import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import '../../data/models/attendance_request_model.dart';
import '../providers/attendance_requests_provider.dart';

/// Inline Approve / Reject buttons.
/// - Approve: tap -> optional note sheet -> confirm.
/// - Reject:  tap -> pick a quick reason chip (or type one) -> done.
/// Use it on the list card AND inside the details sheet.
class ReviewActionBar extends ConsumerStatefulWidget {
  final AttendanceRequest req;

  /// Optional: if a note is already typed elsewhere, the sheets are skipped.
  /// (Can be removed once the details sheet no longer has an "Add note" field.)
  final TextEditingController? noteController;

  /// Called after a successful approve/reject (e.g. close the sheet).
  final VoidCallback? onDone;

  const ReviewActionBar({
    super.key,
    required this.req,
    this.noteController,
    this.onDone,
  });

  @override
  ConsumerState<ReviewActionBar> createState() => _ReviewActionBarState();
}

class _ReviewActionBarState extends ConsumerState<ReviewActionBar> {
  String? _busy;

  bool get _isPending => widget.req.status.toUpperCase() == 'PENDING';

  Future<void> _submit(String status, {String? note}) async {
    if (!_isPending || _busy != null) return;

    HapticFeedback.lightImpact();
    setState(() => _busy = status);

    try {
      await ref
          .read(attendanceRequestsProvider.notifier)
          .updateStatus(id: widget.req.id, status: status, note: note);

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess(
            status == 'approve' ? 'Request approved' : 'Request rejected',
          );

      widget.onDone?.call();
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String? get _typedNote {
    final t = widget.noteController?.text.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<void> _approve() async {
    if (!_isPending || _busy != null) return;

    // Note already typed elsewhere -> approve directly.
    final typed = _typedNote;
    if (typed != null) {
      await _submit('approve', note: typed);
      return;
    }

    final note = await showApproveNoteSheet(context, req: widget.req);
    if (note == null) return; // dismissed -> cancel
    await _submit('approve', note: note.isEmpty ? null : note);
  }

  Future<void> _reject() async {
    if (!_isPending || _busy != null) return;

    final typed = _typedNote;
    if (typed != null) {
      await _submit('reject', note: typed);
      return;
    }

    final reason = await showRejectReasonSheet(context);
    if (reason == null) return; // dismissed -> cancel
    await _submit('reject', note: reason.isEmpty ? null : reason);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPending) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final busy = _busy != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: busy ? null : _reject,
            icon: _busy == 'reject'
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: busy ? null : _approve,
            icon: _busy == 'approve'
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APPROVE SHEET
// ─────────────────────────────────────────────────────────────

/// Returns:
///  - null   -> user dismissed (cancel approve)
///  - ''     -> approve without a note
///  - 'text' -> approve with this note
Future<String?> showApproveNoteSheet(
  BuildContext context, {
  required AttendanceRequest req,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ApproveNoteSheet(req: req),
  );
}

class _ApproveNoteSheet extends StatefulWidget {
  final AttendanceRequest req;
  const _ApproveNoteSheet({required this.req});

  @override
  State<_ApproveNoteSheet> createState() => _ApproveNoteSheetState();
}

class _ApproveNoteSheetState extends State<_ApproveNoteSheet> {
  final _controller = TextEditingController();
  static const _green = Color(0xFF22C55E);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded, color: _green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approve request',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.req.userName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Add a note for the employee',
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _done,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _controller.text.trim().isEmpty
                    ? 'Approve'
                    : 'Approve with note',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REJECT SHEET (unchanged)
// ─────────────────────────────────────────────────────────────

/// Returns:
///  - null      -> user dismissed (cancel reject)
///  - ''        -> reject without a reason
///  - 'text'    -> reject with this reason
Future<String?> showRejectReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _RejectReasonSheet(),
  );
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final _controller = TextEditingController();

  static const _quickReasons = [
    'Insufficient details',
    'Incorrect time',
    'Not as per policy',
    'Please resubmit',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done(String reason) => Navigator.pop(context, reason.trim());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reject request',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a reason to reject instantly',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _quickReasons)
                ActionChip(label: Text(r), onPressed: () => _done(r)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => _done(v),
            decoration: InputDecoration(
              hintText: 'Or type a custom reason',
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded),
                onPressed: () => _done(_controller.text),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _done(''),
              child: const Text('Reject without reason'),
            ),
          ),
        ],
      ),
    );
  }
}