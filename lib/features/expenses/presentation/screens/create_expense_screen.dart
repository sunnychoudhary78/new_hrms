import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/expenses/data/models/expense_model.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../providers/expense_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/add_item_sheet.dart';
import '../widgets/expense_remarks_dialog.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  /// When set, screen loads this draft and saves via `PUT /expenses/:id`.
  final ExpenseClaim? editClaim;

  const CreateExpenseScreen({super.key, this.editClaim});

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final titleController = TextEditingController();

  List<Map<String, dynamic>> items = [];

  File? selectedFile;
  final picker = ImagePicker();

  bool _isSubmitting = false;

  /// ✅ ENUM LIST (MATCH BACKEND)
  final List<String> categories = [
    "Travel",
    "Accommodation",
    "Food",
    "Communication",
    "Stationery",
    "Other",
  ];

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  int _receiptCount(Map<String, dynamic> item) {
    final v = item['_receiptPaths'] ?? item['receipt_paths'];
    int local = 0;
    if (v is List) {
      local = v
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .length;
    }
    final ex = item['_existingReceiptFiles'];
    int kept = 0;
    if (ex is List) {
      kept = ex
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .length;
    }
    return local + kept;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.editClaim;
    if (c != null) {
      titleController.text = c.title;
      items = [
        for (final e in c.items)
          {
            'category': e.category,
            'description': e.description ?? '',
            'amount': e.amount,
            'expense_date': e.expenseDate ?? formatDate(DateTime.now()),
            '_receiptPaths': <String>[],
            '_existingReceiptFiles': List<String>.from(e.receiptFiles),
          },
      ];
    }
  }

  /// Deep copy items and attach optional [selectedFile] to the first line (API contract).
  List<Map<String, dynamic>> _itemsPayloadForSubmit() {
    final out = <Map<String, dynamic>>[];
    for (final raw in items) {
      out.add(Map<String, dynamic>.from(raw));
    }
    final extra = selectedFile?.path.trim();
    if (extra != null && extra.isNotEmpty && out.isNotEmpty) {
      final first = out.first;
      final paths = <String>[
        ...((first['_receiptPaths'] as List?) ?? const [])
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty),
      ];
      if (!paths.contains(extra)) {
        paths.insert(0, extra);
      }
      first['_receiptPaths'] = paths;
    }
    return out;
  }

  /// 🚀 ADD / EDIT ITEM (BOTTOM SHEET)
  void openItemSheet({int? index}) {
    final editingItem = index == null
        ? null
        : Map<String, dynamic>.from(items[index]);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: defaultTargetPlatform == TargetPlatform.iOS,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            defaultTargetPlatform == TargetPlatform.iOS ? 14 : 28,
          ),
        ),
      ),
      builder: (_) => AddItemSheet(
        categories: categories,
        initialItem: editingItem,
        onAdd: (item) {
          if (index == null) {
            items.add(item);
          } else {
            items[index] = item;
          }
          setState(() {});
        },
      ),
    );
  }

  /// 📎 FILE PICK
  Future<void> pickFile() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => selectedFile = File(picked.path));
    }
  }

  Future<void> submit({bool submitForApproval = false}) async {
    if (_isSubmitting) return;

    if (titleController.text.trim().isEmpty) {
      _show("Title required");
      return;
    }

    if (items.isEmpty) {
      _show("Add at least one item");
      return;
    }

    String? submitRemarks;
    if (submitForApproval) {
      submitRemarks = await showExpenseRemarksDialog(
        context,
        title: 'Submit for approval',
        confirmLabel: 'Submit',
        hint: 'Notes for approvers (required)',
      );
      if (!mounted || submitRemarks == null || submitRemarks.isEmpty) {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = _itemsPayloadForSubmit();
      final editing = widget.editClaim;

      if (editing != null) {
        await ref
            .read(createExpenseProvider.notifier)
            .updateDraft(
              claimId: editing.id,
              title: titleController.text.trim(),
              items: payload,
              submit: submitForApproval,
              submitRemarks: submitRemarks,
            );
      } else {
        await ref
            .read(createExpenseProvider.notifier)
            .createExpense(
              title: titleController.text.trim(),
              items: payload,
              submit: submitForApproval,
              submitRemarks: submitRemarks,
            );
      }

      final state = ref.read(createExpenseProvider);

      if (!state.hasError) {
        ref.invalidate(myExpensesProvider);
        ref.invalidate(expenseDashboardProvider);
        final overlay = ref.read(globalLoadingProvider.notifier);
        if (submitForApproval) {
          overlay.showSuccess('Expense submitted for approval');
        } else if (editing != null) {
          overlay.showSuccess('Draft updated');
        } else {
          overlay.showSuccess('Draft saved');
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        ref.read(globalLoadingProvider.notifier).showError('${state.error}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _show(String msg) {
    // Validation / local hints: quick message overlay (not full success flow)
    ref.read(globalLoadingProvider.notifier).showError(msg);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(createExpenseProvider);
    final canInteract = !state.isLoading && !_isSubmitting;
    final isEditingDraft = widget.editClaim != null;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();
    final fieldRadius = isIOS ? 12.0 : 14.0;
    final btnRadius = BorderRadius.circular(isIOS ? 12 : 14);

    return Scaffold(
      appBar: AppAppBar(
        title: isEditingDraft ? "Edit draft" : "Create Expense",
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: btnRadius),
                ),
                onPressed: canInteract ? () => submit() : null,
                child: (state.isLoading || _isSubmitting)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditingDraft ? "Update draft" : "Save as Draft"),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: btnRadius),
                ),
                onPressed: canInteract
                    ? () => submit(submitForApproval: true)
                    : null,
                child: const Text("Submit for Approval"),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          PremiumFeatureHeader(
            icon: Icons.request_quote,
            title: isEditingDraft ? "Edit expense draft" : "Create Expense",
            subtitle: isEditingDraft
                ? "Update line items and receipts, then save or submit for approval."
                : "Add itemized expenses, attach receipts and save a draft or submit for approval.",
          ),
          Expanded(
            child: ListView(
              physics: scrollPhysics,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: "Title *",
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(fieldRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canInteract ? () => openItemSheet() : null,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Item"),
                ),
                const SizedBox(height: 12),
                if (items.isNotEmpty)
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return PremiumCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        title: Text(
                          item['category'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['description'] ?? ""),
                            if (isEditingDraft &&
                                item['_existingReceiptFiles'] is List &&
                                (item['_existingReceiptFiles'] as List)
                                    .where(
                                      (e) =>
                                          e != null &&
                                          e.toString().trim().isNotEmpty,
                                    )
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final name in List<String>.from(
                                    (item['_existingReceiptFiles'] as List)
                                        .map((e) => e?.toString().trim() ?? '')
                                        .where((s) => s.isNotEmpty),
                                  ))
                                    InputChip(
                                      label: Text(
                                        name.contains('/')
                                            ? name.split('/').last
                                            : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onDeleted: !canInteract
                                          ? null
                                          : () {
                                              setState(() {
                                                final cur = List<String>.from(
                                                  item['_existingReceiptFiles']
                                                          as List? ??
                                                      const [],
                                                );
                                                cur.remove(name);
                                                item['_existingReceiptFiles'] =
                                                    cur;
                                              });
                                            },
                                    ),
                                ],
                              ),
                            ],
                            if (_receiptCount(item) > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${_receiptCount(item)} receipt(s) for this line",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "₹${item['amount']}",
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              tooltip: "Edit item",
                              icon: const Icon(Icons.edit_outlined),
                              color: scheme.primary,
                              style: IconButton.styleFrom(
                                splashFactory: isIOS
                                    ? NoSplash.splashFactory
                                    : InkSplash.splashFactory,
                              ),
                              onPressed: !canInteract
                                  ? null
                                  : () => openItemSheet(index: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              style: IconButton.styleFrom(
                                splashFactory: isIOS
                                    ? NoSplash.splashFactory
                                    : InkSplash.splashFactory,
                              ),
                              onPressed: !canInteract
                                  ? null
                                  : () {
                                      items.removeAt(i);
                                      setState(() {});
                                    },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 4),
                PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedFile == null
                              ? "Optional: extra receipt added to the first line"
                              : "Extra receipt will upload with the first line",
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      TextButton(
                        onPressed: canInteract ? pickFile : null,
                        child: const Text("Upload"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
