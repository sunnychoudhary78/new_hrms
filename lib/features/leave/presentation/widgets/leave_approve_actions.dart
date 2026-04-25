import 'package:flutter/material.dart';
import 'package:lms/features/leave/data/models/leave_approve_model.dart';

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
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text("Approve"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (!_canShowPartialApprove) {
                final comment = await _askApproveComment(context);
                if (comment == null) return;

                final confirm = await _confirm(context, "Approve Leave?");
                if (!confirm) return;

                await onApprove(request.id, "approve", comment, null);
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
                final confirm = await _confirm(context, "Approve Leave?");
                if (!confirm) return;

                await onApprove(request.id, "approve", comment, null);
                return;
              }

              final selectedDates = await _askPartialDates(context);
              if (selectedDates == null || selectedDates.isEmpty) return;

              final confirm = await _confirm(
                context,
                "Partially approve selected dates?",
              );
              if (!confirm) return;

              await onApprove(
                request.id,
                "partial_approve",
                comment,
                selectedDates,
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text("Reject"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Future<bool> _confirm(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("Reject Leave"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter reason",
              errorText: errorText,
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() {
                    errorText = "Comment is required";
                  });
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text("Reject"),
            ),
          ],
        ),
      ),
    );
  }

  Future<_ApproveAction?> _askApproveType(BuildContext context) {
    return showDialog<_ApproveAction>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Approve Leave"),
        content: const Text("Choose approval type"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, _ApproveAction.partial),
            child: const Text("Partial Approve"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _ApproveAction.approve),
            child: const Text("Approve"),
          ),
        ],
      ),
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
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isPartial ? "Partial Approve Leave" : "Approve Leave"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter comment",
              errorText: errorText,
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() {
                    errorText = "Comment is required";
                  });
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _askPartialDates(BuildContext context) {
    final requested = _requestedDateOptions();
    if (requested.isEmpty) return Future.value(null);

    final selected = requested.toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("Partial Approve Dates"),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: requested
                    .map(
                      (date) => CheckboxListTile(
                        value: selected.contains(date),
                        title: Text(date),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(date);
                            } else {
                              selected.remove(date);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        requested
                            .where((date) => selected.contains(date))
                            .toList(),
                      ),
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
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
        "${current.year.toString().padLeft(4, '0')}-"
        "${current.month.toString().padLeft(2, '0')}-"
        "${current.day.toString().padLeft(2, '0')}",
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
      return "${parsed.year.toString().padLeft(4, '0')}-"
          "${parsed.month.toString().padLeft(2, '0')}-"
          "${parsed.day.toString().padLeft(2, '0')}";
    } catch (_) {
      // Keep backend-provided value if already date-only or non-ISO.
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
  }

}

enum _ApproveAction { approve, partial }
