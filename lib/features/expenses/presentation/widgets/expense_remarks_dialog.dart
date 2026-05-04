import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/core/providers/global_loading_provider.dart';
import '../utils/expense_remarks_validation.dart';

/// Mandatory remarks with a 150-word cap (used for submit / approve / reject).
Future<String?> showExpenseRemarksDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String hint = 'Visible on claim history',
}) {
  return showDialog<String?>(
    context: context,
    builder: (ctx) => _ExpenseRemarksDialog(
      title: title,
      confirmLabel: confirmLabel,
      hint: hint,
    ),
  );
}

class _ExpenseRemarksDialog extends StatefulWidget {
  const _ExpenseRemarksDialog({
    required this.title,
    required this.confirmLabel,
    required this.hint,
  });

  final String title;
  final String confirmLabel;
  final String hint;

  @override
  State<_ExpenseRemarksDialog> createState() => _ExpenseRemarksDialogState();
}

class _ExpenseRemarksDialogState extends State<_ExpenseRemarksDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final err = expenseRemarksValidationError(_controller.text, required: true);
    if (err != null) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(globalLoadingProvider.notifier).showError(err);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final wc = expenseRemarksWordCount(text);
    final t = text.trim();
    // Empty: block confirm only, no error line. Word limit: show [errorText].
    final err = t.isEmpty
        ? null
        : expenseRemarksValidationError(text, required: true);
    final canSubmit = err == null && t.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: TextField(
            controller: _controller,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Remarks *',
              hintText: widget.hint,
              helperText: t.isNotEmpty
                  ? '$wc / $kExpenseRemarksMaxWords words max'
                  : 'Required to continue',
              errorText: err,
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit ? _confirm : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
