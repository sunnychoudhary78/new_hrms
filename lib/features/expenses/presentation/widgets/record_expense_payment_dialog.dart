import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/core/providers/global_loading_provider.dart';
import '../utils/expense_remarks_validation.dart';

/// Accounts “record payment” — remarks (required) + fixed payment modes + reference.
class ExpensePaymentFormResult {
  const ExpensePaymentFormResult({
    required this.remarks,
    required this.paymentMode,
    required this.paymentReference,
  });

  final String remarks;
  final String paymentMode;
  final String paymentReference;
}

/// Payment mode values sent to the API (`payment_mode`).
const List<String> kExpensePaymentModeOptions = [
  'Bank transfer',
  'Cash',
  'Cheque',
  'UPI',
  'Other',
];

Future<ExpensePaymentFormResult?> showRecordExpensePaymentDialog(
  BuildContext context,
) {
  return showDialog<ExpensePaymentFormResult?>(
    context: context,
    builder: (ctx) => const _RecordExpensePaymentDialog(),
  );
}

class _RecordExpensePaymentDialog extends StatefulWidget {
  const _RecordExpensePaymentDialog();

  @override
  State<_RecordExpensePaymentDialog> createState() =>
      _RecordExpensePaymentDialogState();
}

class _RecordExpensePaymentDialogState
    extends State<_RecordExpensePaymentDialog> {
  final _remarks = TextEditingController();
  final _reference = TextEditingController();
  String _mode = kExpensePaymentModeOptions.first;

  static const _dialogRadius = 28.0;
  static const _fieldRadius = 18.0;
  static const _fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );

  @override
  void dispose() {
    _remarks.dispose();
    _reference.dispose();
    super.dispose();
  }

  InputDecoration _outlineFieldDecoration(ColorScheme scheme) {
    return InputDecoration(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: _fieldPadding,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    );
  }

  void _confirm(BuildContext ctx) {
    final refErr = _reference.text.trim().isEmpty
        ? 'Payment reference is required.'
        : null;
    if (refErr != null) {
      ProviderScope.containerOf(
        ctx,
        listen: false,
      ).read(globalLoadingProvider.notifier).showError(refErr);
      return;
    }

    final remarkErr = expenseRemarksValidationError(
      _remarks.text,
      required: true,
    );
    if (remarkErr != null) {
      ProviderScope.containerOf(
        ctx,
        listen: false,
      ).read(globalLoadingProvider.notifier).showError(remarkErr);
      return;
    }

    Navigator.pop(
      ctx,
      ExpensePaymentFormResult(
        remarks: _remarks.text.trim(),
        paymentMode: _mode,
        paymentReference: _reference.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final maxDialogHeight = (media.size.height - media.viewInsets.bottom - 48)
        .clamp(360.0, 620.0);
    final wc = expenseRemarksWordCount(_remarks.text);
    final rTrim = _remarks.text.trim();
    final refTrim = _reference.text.trim();
    final remarkErr = rTrim.isEmpty
        ? null
        : expenseRemarksValidationError(_remarks.text, required: true);
    final canConfirm =
        rTrim.isNotEmpty && refTrim.isNotEmpty && remarkErr == null;

    final fieldDeco = _outlineFieldDecoration(scheme);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dialogRadius),
      ),
      clipBehavior: Clip.none,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxDialogHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(_dialogRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_dialogRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primaryContainer,
                        scheme.secondaryContainer,
                        scheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.24),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.payments_rounded,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record payment',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Capture the settlement method, proof reference, and final notes for this expense claim.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Close',
                        onPressed: () =>
                            Navigator.pop<ExpensePaymentFormResult?>(
                              context,
                              null,
                            ),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                          backgroundColor: scheme.surface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PaymentModeSelector(
                          value: _mode,
                          onChanged: (value) => setState(() => _mode = value),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reference,
                          style: theme.textTheme.bodyLarge,
                          onChanged: (_) => setState(() {}),
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                          decoration: fieldDeco.copyWith(
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            labelText: 'Payment reference *',
                            hintText: 'UTR, cheque no., receipt no.',
                            helperText: 'Required before confirming payment',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _remarks,
                          maxLines: 4,
                          minLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge,
                          onChanged: (_) => setState(() {}),
                          decoration: fieldDeco.copyWith(
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 56),
                              child: Icon(
                                Icons.notes_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            labelText: 'Remarks *',
                            hintText: 'Add a clear note for the claim history',
                            helperText: rTrim.isNotEmpty
                                ? '$wc / $kExpenseRemarksMaxWords words max'
                                : 'Required before confirming payment',
                            errorText: remarkErr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.68),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop<ExpensePaymentFormResult?>(
                                context,
                                null,
                              ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: canConfirm
                              ? () => _confirm(context)
                              : null,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Confirm payment'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            textStyle: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentModeSelector extends StatelessWidget {
  const _PaymentModeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  IconData _iconForMode(String mode) {
    return switch (mode) {
      'Bank transfer' => Icons.account_balance_rounded,
      'Cash' => Icons.payments_outlined,
      'Cheque' => Icons.receipt_long_rounded,
      'UPI' => Icons.qr_code_2_rounded,
      _ => Icons.more_horiz_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopupMenuButton<String>(
      initialValue: value,
      tooltip: 'Select payment mode',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 10,
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      constraints: const BoxConstraints(minWidth: 260),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final mode in kExpensePaymentModeOptions)
          PopupMenuItem<String>(
            value: mode,
            child: Row(
              children: [
                Icon(
                  _iconForMode(mode),
                  size: 20,
                  color: mode == value
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: mode == value ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (mode == value)
                  Icon(Icons.check_rounded, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForMode(value), color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment mode',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
