import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/attendance/correction_attendance/data/models/attendance_request_model.dart';

class MyCorrectionCard extends StatefulWidget {
  final AttendanceRequest request;
  final bool autoExpand;

  const MyCorrectionCard({
    super.key,
    required this.request,
    this.autoExpand = false,
  });

  @override
  State<MyCorrectionCard> createState() => _MyCorrectionCardState();
}

class _MyCorrectionCardState extends State<MyCorrectionCard> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.autoExpand;
  }

  @override
  void didUpdateWidget(covariant MyCorrectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoExpand && !oldWidget.autoExpand) {
      setState(() {
        isExpanded = true;
      });
    }
  }

  Color _statusColor(ColorScheme scheme) {
    switch (widget.request.status) {
      case 'APPROVED':
        return Colors.green;

      case 'REJECTED':
        return scheme.error;

      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  String _formatDate(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;

    return DateFormat('EEE, d MMM yyyy').format(dt);
  }

  String _formatTime(String? iso) {
    if (iso == null) return "--";

    final dt = DateTime.tryParse(iso);
    if (dt == null) return "--";

    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final req = widget.request;

    final statusColor = _statusColor(scheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? scheme.primary.withOpacity(0.4)
              : scheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  /// Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      req.isCorrection
                          ? Icons.edit_calendar_rounded
                          : Icons.home_work_rounded,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.isCorrection
                              ? "Attendance Correction"
                              : "Remote Work Request",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _formatDate(req.targetDate),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      req.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          /// EXPANDED CONTENT
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: scheme.outline.withOpacity(0.2)),

                  const SizedBox(height: 8),

                  if (req.isCorrection) ...[
                    _InfoRow(
                      label: "Proposed Check-in",
                      value: _formatTime(req.proposedCheckIn),
                    ),

                    _InfoRow(
                      label: "Proposed Check-out",
                      value: _formatTime(req.proposedCheckOut),
                    ),

                    const SizedBox(height: 8),
                  ],

                  _InfoRow(label: "Reason", value: req.reason ?? "--"),

                  const SizedBox(height: 8),

                  _InfoRow(
                    label: "Requested at",
                    value: req.requestedAt != null
                        ? _formatDate(req.requestedAt!)
                        : "--",
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
