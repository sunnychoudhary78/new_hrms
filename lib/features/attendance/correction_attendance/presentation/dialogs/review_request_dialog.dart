import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_request_model.dart';
import '../providers/attendance_requests_provider.dart';

void showReviewDialog({
  required BuildContext context,
  required AttendanceRequest req,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewDialog(req: req),
  );
}

class _ReviewDialog extends ConsumerStatefulWidget {
  final AttendanceRequest req;

  const _ReviewDialog({required this.req});

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  Future<void> _update(String status) async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      await ref
          .read(attendanceRequestsProvider.notifier)
          .updateStatus(
            id: widget.req.id,
            status: status,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Optional: show snackbar here
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final req = widget.req;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Review ${req.type.toLowerCase()} request",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurface),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                req.userName,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),

              const SizedBox(height: 16),

              if (req.isCorrection) ...[
                _InfoRow("Proposed In", req.proposedCheckIn),
                _InfoRow("Proposed Out", req.proposedCheckOut),
                const SizedBox(height: 12),
              ],

              const Text(
                "Reason",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(req.reason ?? "--"),

              const SizedBox(height: 16),

              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Manager Note (optional)",
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _update('reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _update('approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      child: _submitting
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Text("Approve"),
                    ),
                  ),
                ],
              ),
            ],
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
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? '--')),
        ],
      ),
    );
  }
}
