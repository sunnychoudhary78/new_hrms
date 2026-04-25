import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/add_item_sheet.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({super.key});

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
    if (v is! List) return 0;
    return v.where((e) => e != null && e.toString().trim().isNotEmpty).length;
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

  /// 🚀 ADD ITEM (BOTTOM SHEET)
  void openAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddItemSheet(
        categories: categories,
        onAdd: (item) {
          items.add(item);
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
    setState(() => _isSubmitting = true);

    try {
      if (titleController.text.trim().isEmpty) {
        _show("Title required");
        return;
      }

      if (items.isEmpty) {
        _show("Add at least one item");
        return;
      }

      await ref
          .read(createExpenseProvider.notifier)
          .createExpense(
            title: titleController.text.trim(),
            items: _itemsPayloadForSubmit(),
            submit: submitForApproval,
          );

      final state = ref.read(createExpenseProvider);

      if (!state.hasError) {
        Navigator.pop(context);

        _show(submitForApproval ? "Expense Submitted ✅" : "Draft Saved ✅");
      } else {
        _show("Error: ${state.error}");
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(createExpenseProvider);
    final canInteract = !state.isLoading && !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text("Create Expense"), elevation: 0),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canInteract ? () => submit() : null,
                child: (state.isLoading || _isSubmitting)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save as Draft"),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.request_quote, color: scheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Create a clean claim with itemized entries and submit instantly.",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canInteract ? openAddItemSheet : null,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Item"),
                ),
                const SizedBox(height: 12),
                if (items.isNotEmpty)
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: scheme.surfaceContainerLow,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        title: Text(
                          item['category'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['description'] ?? ""),
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
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
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
