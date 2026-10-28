import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/leave/data/models/leave_approve_model.dart';

const Color _kApproveAccent = Color(0xFF0F766E);

/// Result returned by the approve bottom sheet.
class _ApproveResult {
  final String action;
  final String? comment;
  final List<String>? dates;

  const _ApproveResult(this.action, this.comment, this.dates);
}

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = BorderRadius.circular(isIOS ? 12 : 14);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            onPressed: () => _handleReject(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(_isRevocation ? 'Approve revoke' : 'Approve'),
            style: FilledButton.styleFrom(
              backgroundColor: _kApproveAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            onPressed: () => _handleApprove(context),
          ),
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////
  /// HANDLERS — ONE SHEET EACH
  //////////////////////////////////////////////////////////////

  Future<void> _handleApprove(BuildContext context) async {
    final result = await showModalBottomSheet<_ApproveResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ApproveSheet(
        request: request,
        dateOptions: _requestedDateOptions(),
        canPartial: _canShowPartialApprove,
        isRevocation: _isRevocation,
      ),
    );

    if (result == null) return;

    await onApprove(request.id, result.action, result.comment, result.dates);
  }

  Future<void> _handleReject(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RejectSheet(request: request),
    );

    if (reason == null) return;

    await onReject(request.id, reason.isEmpty ? null : reason);
  }

  //////////////////////////////////////////////////////////////
  /// HELPERS
  //////////////////////////////////////////////////////////////

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

  bool get _isRevocation =>
      request.status.trim().toLowerCase() == 'revocationrequested';

  bool get _canShowPartialApprove {
    if (_isRevocation) return false;
    if (request.isHalfDay) return false;
    return _requestedDateOptions().length > 1;
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
}

//////////////////////////////////////////////////////////////
/// APPROVE SHEET
//////////////////////////////////////////////////////////////

class _ApproveSheet extends StatefulWidget {
  final ManagerLeaveRequest request;
  final List<String> dateOptions;
  final bool canPartial;
  final bool isRevocation;

  const _ApproveSheet({
    required this.request,
    required this.dateOptions,
    required this.canPartial,
    required this.isRevocation,
  });

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  final _comment = TextEditingController();
  bool _partial = false;
  late final Set<String> _selected = widget.dateOptions.toSet();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String _fmt(String ymd) {
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    return DateFormat('EEE, d MMM').format(d);
  }

  void _submit() {
    final comment = _comment.text.trim();
    final c = comment.isEmpty ? null : comment;

    if (_partial) {
      final dates =
          widget.dateOptions.where((d) => _selected.contains(d)).toList();
      Navigator.pop(context, _ApproveResult('partial_approve', c, dates));
    } else {
      Navigator.pop(
        context,
        _ApproveResult(
          widget.isRevocation ? 'approve_revocation' : 'approve',
          c,
          null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.request;

    final totalDays = widget.dateOptions.length;
    final canConfirm = !_partial || _selected.isNotEmpty;

    final confirmLabel = widget.isRevocation
        ? 'Approve revocation'
        : _partial
            ? 'Approve ${_selected.length} of $totalDays days'
            : 'Approve leave';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isRevocation ? 'Approve revocation' : 'Approve leave',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.employeeName} • ${r.leaveType}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            /// Full vs selected dates — only for multi-day requests
            if (widget.canPartial) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('All $totalDays days'),
                    ),
                    const ButtonSegment(
                      value: true,
                      label: Text('Select dates'),
                    ),
                  ],
                  selected: {_partial},
                  onSelectionChanged: (v) => setState(() {
                    _partial = v.first;
                    if (_partial) _selected.addAll(widget.dateOptions);
                  }),
                ),
              ),
            ],

            if (_partial) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.dateOptions.map((date) {
                  final on = _selected.contains(date);
                  return FilterChip(
                    label: Text(_fmt(date)),
                    selected: on,
                    selectedColor: _kApproveAccent.withValues(alpha: 0.15),
                    checkmarkColor: _kApproveAccent,
                    onSelected: (v) => setState(() {
                      v ? _selected.add(date) : _selected.remove(date);
                    }),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canConfirm ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _kApproveAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// REJECT SHEET
//////////////////////////////////////////////////////////////

class _RejectSheet extends StatefulWidget {
  final ManagerLeaveRequest request;

  const _RejectSheet({required this.request});

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _reason = TextEditingController();

  static const _quickReasons = [
    'Team workload',
    'Insufficient notice',
    'Please reschedule',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.request;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject leave',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.employeeName} • ${r.leaveType}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReasons
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      onPressed: () => setState(() {
                        _reason.text = t;
                        _reason.selection = TextSelection.collapsed(
                          offset: t.length,
                        );
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Add context for the employee…',
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _reason.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Reject leave'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}