import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/widgets/quick_actions.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import '../../data/models/attendance_request_model.dart';

void showReviewDialog({
  required BuildContext context,
  required AttendanceRequest req,
}) {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: isIOS,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewDialog(req: req),
  );
}

class _ReviewDialog extends StatefulWidget {
  final AttendanceRequest req;

  const _ReviewDialog({required this.req});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _noteController = TextEditingController();
  bool _showNote = false;

  bool get _isPending => widget.req.status.toUpperCase() == 'PENDING';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _statusColor(ColorScheme scheme) {
    switch (widget.req.status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF22C55E);
      case 'REJECTED':
        return scheme.error;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final req = widget.req;
    final isPending = _isPending;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final topRadius = isIOS ? 14.0 : 20.0;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(topRadius),
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: isIOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: title + status + close in one row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.userName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${req.type[0].toUpperCase()}${req.type.substring(1).toLowerCase()} request',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(scheme),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          req.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close, color: scheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (req.isCorrection) ...[
                  _InfoRow(
                    'Proposed In',
                    formatIsoToLocalTime(req.proposedCheckIn),
                  ),
                  _InfoRow(
                    'Proposed Out',
                    formatIsoToLocalTime(req.proposedCheckOut),
                  ),
                  const SizedBox(height: 8),
                ],

                const Text(
                  'Reason',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(req.reason ?? '--'),

                if (isPending) ...[
                  const SizedBox(height: 8),

                  // Note is optional and hidden by default -> no extra step.
                  if (!_showNote)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showNote = true),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: const Text('Add note'),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _noteController,
                        autofocus: true,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Manager note (optional)',
                          filled: true,
                          fillColor: scheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isIOS ? 12 : 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  ReviewActionBar(
                    req: req,
                    onDone: () =>
                        Navigator.pop(context), // sheet close after success
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? '--')),
        ],
      ),
    );
  }
}
