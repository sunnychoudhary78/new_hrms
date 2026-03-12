import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_design.dart';
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
        return scheme.primary;
      case 'REJECTED':
        return scheme.error;
      case 'PENDING':
      default:
        return scheme.tertiary;
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isExpanded
              ? scheme.primary.withOpacity(0.4)
              : scheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  /// Icon
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      req.isCorrection
                          ? Icons.edit_calendar_rounded
                          : Icons.home_work_rounded,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm + 4),

                  /// Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.isCorrection
                              ? "Attendance Correction"
                              : "Remote Work Request",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: AppSpacing.xs),

                        Text(
                          _formatDate(req.targetDate),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  /// Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      req.status,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: scheme.outline.withOpacity(0.2)),

                  const SizedBox(height: AppSpacing.sm),

                  if (req.isCorrection) ...[
                    _InfoRow(
                      label: "Proposed Check-in",
                      value: _formatTime(req.proposedCheckIn),
                    ),
                    _InfoRow(
                      label: "Proposed Check-out",
                      value: _formatTime(req.proposedCheckOut),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  _InfoRow(label: "Reason", value: req.reason ?? "--"),

                  const SizedBox(height: AppSpacing.sm),

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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
