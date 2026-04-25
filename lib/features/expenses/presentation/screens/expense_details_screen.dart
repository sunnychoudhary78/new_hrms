import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/expenses/presentation/screens/expense_receipt_preview_screen.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({super.key});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _isSubmitting = false;
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ExpenseClaim expense =
        ModalRoute.of(context)!.settings.arguments as ExpenseClaim;
    final role = ref.watch(expenseDashboardRoleProvider);
    final normalizedStatus = expense.status.toLowerCase();
    final canApprove = _canApprove(role, normalizedStatus);
    final canProcess = _canProcess(role, normalizedStatus);
    final canReject = _canReject(role, normalizedStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Details"),
        elevation: 0,
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [scheme.primaryContainer, scheme.secondaryContainer],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primary,
                        child: Icon(Icons.receipt_long, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _statusChip(expense.status),
                          ],
                        ),
                      ),
                      Text(
                        "₹${expense.totalAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Items",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...expense.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Line ${index + 1}: ${item.category}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (item.description != null &&
                                        item.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description!,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    if (item.expenseDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "Date: ${item.expenseDate}",
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                "₹${item.amount}",
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: scheme.outlineVariant),
                          const SizedBox(height: 10),
                          Text(
                            "Attached documents",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (item.receiptFiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                "No document attached for this line.",
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            ...item.receiptFiles.asMap().entries.map((e) {
                              final ref = e.value.trim();
                              return _documentTile(
                                context: context,
                                scheme: scheme,
                                fileRef: ref,
                                title: item.receiptFiles.length > 1
                                    ? "Document ${e.key + 1}"
                                    : "Receipt",
                                subtitle: _displayFileName(ref),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          if (expense.status == "Draft")
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitExpense(expense.id),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Submit for Approval"),
                ),
              ),
            ),

          if (canApprove || canProcess || canReject)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (canReject) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.errorContainer,
                          foregroundColor: scheme.onErrorContainer,
                        ),
                        onPressed: _isActionLoading
                            ? null
                            : () => _rejectExpense(expense.id),
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close),
                        label: const Text("Reject"),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (canApprove || canProcess)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActionLoading
                            ? null
                            : () => canApprove
                                  ? _approveExpense(expense.id)
                                  : _payExpense(expense.id),
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                canApprove ? Icons.check_circle : Icons.task_alt,
                              ),
                        label: Text(
                          canApprove ? "Approve Expense" : "Record payment",
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitExpense(String id) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(expenseRepositoryProvider).submitExpense(id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Submitted successfully ✅")));

      Navigator.pop(context);
      ref.invalidate(myExpensesProvider);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _approveExpense(String id) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);

    try {
      await ref.read(expenseRepositoryProvider).approveExpense(id);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Expense approved ✅")));

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _payExpense(String id) async {
    if (_isActionLoading) return;

    final remarksCtrl = TextEditingController();
    final modeCtrl = TextEditingController(text: 'NEFT');
    final refCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payment mode',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payment reference',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (refCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Payment reference is required'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    final remarksText = remarksCtrl.text.trim();
    final modeText = modeCtrl.text.trim();
    final refText = refCtrl.text.trim();
    remarksCtrl.dispose();
    modeCtrl.dispose();
    refCtrl.dispose();

    if (!mounted || confirmed != true) return;

    setState(() => _isActionLoading = true);

    try {
      await ref.read(expenseRepositoryProvider).payExpense(
            id,
            remarks: remarksText.isEmpty ? null : remarksText,
            paymentMode: modeText.isEmpty ? null : modeText,
            paymentReference: refText,
          );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded — claim is Processed')),
      );

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _rejectExpense(String id) async {
    if (_isActionLoading) return;

    final remarksController = TextEditingController();
    final remarks = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject expense"),
        content: TextField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: "Remarks (optional)",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, remarksController.text.trim()),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (!mounted || remarks == null) return;

    setState(() => _isActionLoading = true);

    try {
      await ref.read(expenseRepositoryProvider).rejectExpense(
            id,
            remarks: remarks.isEmpty ? null : remarks,
          );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Expense rejected ✅")));

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  bool _canApprove(ExpenseDashboardRole role, String status) {
    if (role == ExpenseDashboardRole.manager) {
      return status == "pending";
    }
    if (role == ExpenseDashboardRole.hod) {
      return status == "manager approved";
    }
    return false;
  }

  bool _canProcess(ExpenseDashboardRole role, String status) {
    if (role == ExpenseDashboardRole.accounts) {
      return status == "hod approved";
    }
    return false;
  }

  bool _canReject(ExpenseDashboardRole role, String status) {
    if (role == ExpenseDashboardRole.manager) {
      return status == "pending";
    }
    if (role == ExpenseDashboardRole.hod) {
      return status == "manager approved";
    }
    if (role == ExpenseDashboardRole.accounts) {
      return status == "hod approved";
    }
    return false;
  }

  static String _displayFileName(String path) {
    final t = path.trim();
    if (t.isEmpty) return path;
    final parts = t.split(RegExp(r'[/\\]+'));
    return parts.isNotEmpty ? parts.last : t;
  }

  static IconData _docIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }

  Widget _documentTile({
    required BuildContext context,
    required ColorScheme scheme,
    required String fileRef,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: Icon(
          _docIconForName(subtitle),
          color: scheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.primary),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExpenseReceiptPreviewScreen(
                receiptFileName: fileRef,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;

    switch (status) {
      case "Draft":
        color = Colors.grey;
        break;
      case "Pending":
        color = Colors.orange;
        break;
      case "Rejected":
        color = Colors.red;
        break;
      case "Manager Approved":
      case "HOD Approved":
      case "Processed":
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
