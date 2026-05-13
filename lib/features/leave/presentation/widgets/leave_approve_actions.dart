import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/leave/data/models/leave_approve_model.dart';

/// Accent for positive actions — distinct from generic `primary`, tuned for clarity.
const Color _kApproveAccent = Color(0xFF0F766E);

class LeaveApproveActions extends StatelessWidget {
  final ManagerLeaveRequest request;

  final Function(String, String, String?, List<String>?) onApprove;

  final Function(String, String?) onReject;

  const LeaveApproveActions({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  ShapeBorder _dialogShape() {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isIOS ? 14 : 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final actionRadius = BorderRadius.circular(isIOS ? 12 : 14);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text('Approve'),
            style: FilledButton.styleFrom(
              backgroundColor: _kApproveAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: actionRadius,
              ),
            ),
            onPressed: () async {
              if (!_canShowPartialApprove) {
                final comment = await _askApproveComment(context);
                if (comment == null) return;

                final confirm = await _confirm(
                  context,
                  title: 'Approve leave',
                  message:
                      'This will approve the full request using your comment for the audit trail.',
                  confirmLabel: 'Approve',
                );
                if (!confirm) return;

                await onApprove(request.id, 'approve', comment, null);
                return;
              }

              final result = await _askApproveType(context);
              if (result == null) return;

              final comment = await _askApproveComment(
                context,
                isPartial: result == _ApproveAction.partial,
              );
              if (comment == null) return;

              if (result == _ApproveAction.approve) {
                final confirm = await _confirm(
                  context,
                  title: 'Approve leave',
                  message:
                      'All requested dates will be approved with your comment.',
                  confirmLabel: 'Approve',
                );
                if (!confirm) return;

                await onApprove(request.id, 'approve', comment, null);
                return;
              }

              final selectedDates = await _askPartialDates(context);
              if (selectedDates == null || selectedDates.isEmpty) return;

              final confirm = await _confirm(
                context,
                title: 'Confirm partial approval',
                message:
                    '${selectedDates.length} date${selectedDates.length == 1 ? '' : 's'} will be approved.',
                confirmLabel: 'Confirm',
              );
              if (!confirm) return;

              await onApprove(
                request.id,
                'partial_approve',
                comment,
                selectedDates,
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.close_rounded, size: 22),
            label: const Text('Reject'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: actionRadius,
              ),
            ),
            onPressed: () async {
              final reason = await _askReason(context);
              if (reason == null) return;

              await onReject(request.id, reason);
            },
          ),
        ),
      ],
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            return AlertDialog(
              shape: _dialogShape(),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kApproveAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: _kApproveAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (message != null && message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kApproveAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: _dialogShape(),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.cancel_outlined,
                      color: scheme.onErrorContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reject leave',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A clear reason is required for the employee and audit trail.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Reason *',
                      hintText:
                          'Explain why this request cannot be approved…',
                      errorText: errorText,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        errorText = 'Please enter a reason';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject leave'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<_ApproveAction?> _askApproveType(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return showDialog<_ApproveAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: _dialogShape(),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approval type',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This request spans multiple days. Choose how you want to approve.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ApproveTypeCard(
                scheme: scheme,
                icon: Icons.event_available_rounded,
                title: 'Full approval',
                subtitle: 'Approve every day in this request',
                onTap: () =>
                    Navigator.pop(dialogContext, _ApproveAction.approve),
              ),
              const SizedBox(height: 12),
              _ApproveTypeCard(
                scheme: scheme,
                icon: Icons.date_range_rounded,
                title: 'Partial approval',
                subtitle: 'Pick specific dates to approve',
                onTap: () =>
                    Navigator.pop(dialogContext, _ApproveAction.partial),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _askApproveComment(
    BuildContext context, {
    bool isPartial = false,
  }) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: _dialogShape(),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kApproveAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.comment_bank_outlined,
                      color: _kApproveAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPartial
                              ? 'Comment for partial approval'
                              : 'Manager comment',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPartial
                              ? 'Your note will be stored with the approved dates.'
                              : 'Visible to HR and the employee on the request history.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Comment *',
                      hintText: 'Add context for this decision…',
                      errorText: errorText,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        errorText = 'Comment is required';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _kApproveAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>?> _askPartialDates(BuildContext context) {
    final requested = _requestedDateOptions();
    if (requested.isEmpty) return Future.value(null);

    final selected = requested.toSet();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final count = selected.length;

            return AlertDialog(
              shape: _dialogShape(),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.edit_calendar_rounded,
                      color: scheme.onSecondaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select dates to approve',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          count == 0
                              ? 'Choose at least one day.'
                              : '$count day${count == 1 ? '' : 's'} selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: requested.map((date) {
                        final checked = selected.contains(date);
                        return CheckboxTheme(
                          data: CheckboxThemeData(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: checked,
                            title: Text(
                              _formatDisplayDate(date),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              date,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selected.add(date);
                                } else {
                                  selected.remove(date);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            requested
                                .where((date) => selected.contains(date))
                                .toList(),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kApproveAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _requestedDateOptions() {
    if (request.requestedDates.isNotEmpty) {
      final normalized = request.requestedDates
          .map((e) => _normalizeDate(e['date']))
          .where((date) => date.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) return normalized;
    }

    final start = DateTime.tryParse(request.startDate);
    final end = DateTime.tryParse(request.endDate);
    if (start == null || end == null) return [];

    final dates = <String>[];
    var current = start;
    while (!current.isAfter(end)) {
      dates.add(
        '${current.year.toString().padLeft(4, '0')}-'
        '${current.month.toString().padLeft(2, '0')}-'
        '${current.day.toString().padLeft(2, '0')}',
      );
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  bool get _canShowPartialApprove {
    final normalizedStatus = request.status.trim().toLowerCase();
    if (normalizedStatus == 'revocationrequested') return false;
    if (request.isHalfDay) return false;
    final options = _requestedDateOptions();
    return options.length > 1;
  }

  String _normalizeDate(dynamic rawDate) {
    if (rawDate == null) return '';

    final value = rawDate.toString();
    try {
      final parsed = DateTime.parse(value);
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
  }

  String _formatDisplayDate(String ymd) {
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    return DateFormat('EEE, d MMM yyyy').format(d);
  }
}

enum _ApproveAction { approve, partial }

class _ApproveTypeCard extends StatelessWidget {
  const _ApproveTypeCard({
    required this.scheme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
