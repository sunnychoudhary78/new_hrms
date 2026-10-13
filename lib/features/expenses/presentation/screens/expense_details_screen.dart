import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/expenses/presentation/screens/expense_receipt_preview_screen.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_remarks_dialog.dart';
import '../widgets/record_expense_payment_dialog.dart';

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
    final ExpenseClaim expense =
        ModalRoute.of(context)!.settings.arguments as ExpenseClaim;
    final role = ref.watch(expenseDashboardRoleProvider);
    final normalizedStatus = expense.status.toLowerCase();
    final canApprove = _canApprove(role, normalizedStatus);
    final canProcess = _canProcess(role, normalizedStatus);
    final canReject = _canReject(role, normalizedStatus);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: 'Expense Details'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: isIOS
                  ? const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    )
                  : const ClampingScrollPhysics(),
              padding: appScreenPadding,
              children: [
                AppHeroBanner(
                  icon: Icons.receipt_long_rounded,
                  title: expense.title,
                  message:
                      'Total claim · ₹${expense.totalAmount.toStringAsFixed(0)}',
                  trailing: AppStatusPill(label: expense.status),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppSectionTitle('Items'),
                const SizedBox(height: AppSpacing.sm),
                ...expense.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AppSectionCard(
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
                                    'Line ${index + 1}: ${item.category}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  if (item.description != null &&
                                      item.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description!,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  if (item.expenseDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${item.expenseDate}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '₹${item.amount}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.sm + 2),
                        const Text(
                          'Attached documents',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (item.receiptFiles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'No document attached for this line.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ...item.receiptFiles.asMap().entries.map((e) {
                            final fileRef = e.value.trim();
                            return _documentTile(
                              context: context,
                              fileRef: fileRef,
                              title: item.receiptFiles.length > 1
                                  ? 'Document ${e.key + 1}'
                                  : 'Receipt',
                              subtitle: _displayFileName(fileRef),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          if (expense.status == 'Draft')
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: AppPrimaryButton(
                  label: 'Submit for Approval',
                  icon: Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: () => _submitExpense(expense.id),
                ),
              ),
            ),
          if (canApprove || canProcess || canReject)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (canReject) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: _isActionLoading
                              ? null
                              : () => _rejectExpense(expense.id),
                          icon: _isActionLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.close),
                          label: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (canApprove || canProcess)
                      Expanded(
                        child: AppPrimaryButton(
                          label: canApprove
                              ? 'Approve Expense'
                              : 'Record payment',
                          icon: canApprove
                              ? Icons.check_circle_rounded
                              : Icons.task_alt_rounded,
                          isLoading: _isActionLoading,
                          onPressed: () => canApprove
                              ? _approveExpense(expense.id)
                              : _payExpense(expense.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitExpense(String id) async {
    if (_isSubmitting) return;

    final remarks = await showExpenseRemarksDialog(
      context,
      title: 'Submit for approval',
      confirmLabel: 'Submit',
      hint: 'Notes for approvers (required)',
    );
    if (!mounted || remarks == null || remarks.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(expenseRepositoryProvider)
          .submitExpense(id, remarks: remarks);

      if (!mounted) return;

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Submitted — claim is now pending approval');
      ref.invalidate(myExpensesProvider);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _approveExpense(String id) async {
    if (_isActionLoading) return;

    final remarksText = await showExpenseRemarksDialog(
      context,
      title: 'Approve expense',
      confirmLabel: 'Approve',
      hint: 'Comments for audit and next approver (required)',
    );
    if (!mounted || remarksText == null || remarksText.isEmpty) return;

    setState(() => _isActionLoading = true);

    try {
      await ref
          .read(expenseRepositoryProvider)
          .approveExpense(id, remarks: remarksText);
      if (!mounted) return;

      final role = ref.read(expenseDashboardRoleProvider);
      final statusLine = switch (role) {
        ExpenseDashboardRole.manager => 'Manager approved',
        ExpenseDashboardRole.hod => 'HOD approved',
        _ => 'Approved',
      };
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Expense approved — $statusLine');

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ref
          .read(globalLoadingProvider.notifier)
          .showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _payExpense(String id) async {
    if (_isActionLoading) return;

    final result = await showRecordExpensePaymentDialog(context);
    if (!mounted || result == null) return;

    setState(() => _isActionLoading = true);

    try {
      await ref
          .read(expenseRepositoryProvider)
          .payExpense(
            id,
            remarks: result.remarks,
            paymentMode: result.paymentMode,
            paymentReference: result.paymentReference,
          );
      if (!mounted) return;

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Payment recorded — claim is now processed');

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ref
          .read(globalLoadingProvider.notifier)
          .showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _rejectExpense(String id) async {
    if (_isActionLoading) return;

    final remarks = await showExpenseRemarksDialog(
      context,
      title: 'Reject expense',
      confirmLabel: 'Reject',
      hint: 'Reason for rejection (required for audit trail)',
    );

    if (!mounted || remarks == null || remarks.isEmpty) return;

    setState(() => _isActionLoading = true);

    try {
      await ref
          .read(expenseRepositoryProvider)
          .rejectExpense(id, remarks: remarks);
      if (!mounted) return;

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Expense rejected — status updated');

      ref.invalidate(expenseDashboardProvider);
      ref.invalidate(myExpensesProvider);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ref
          .read(globalLoadingProvider.notifier)
          .showError(e.toString().replaceFirst('Exception: ', ''));
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
    required String fileRef,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: AppColors.softFill,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: Icon(_docIconForName(subtitle), color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.title,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ExpenseReceiptPreviewScreen(receiptFileName: fileRef),
            ),
          );
        },
      ),
    );
  }
}
