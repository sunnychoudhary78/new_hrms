import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
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
  String? _submittingAction;

  Future<void> _update(String status) async {
    if (_submittingAction != null) return;

    setState(() => _submittingAction = status);

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

      final actionText = status == 'approve' ? 'approved' : 'rejected';
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess("Correction request $actionText successfully");

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).showError(e.toString());
    } finally {
      if (mounted) setState(() => _submittingAction = null);
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
    final isSubmitting = _submittingAction != null;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.primaryContainer,
                ),
                child: Row(
                  children: [
                    Icon(Icons.rule_folder_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Review ${req.type.toLowerCase()} request",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      req.userName,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurface),
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
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
                    child: FilledButton.tonalIcon(
                      onPressed: isSubmitting ? null : () => _update('reject'),
                      icon: const Icon(Icons.close_rounded),
                      label: _submittingAction == 'reject'
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
                    child: FilledButton.icon(
                      onPressed: isSubmitting ? null : () => _update('approve'),
                      icon: const Icon(Icons.check_rounded),
                      label: _submittingAction == 'approve'
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
