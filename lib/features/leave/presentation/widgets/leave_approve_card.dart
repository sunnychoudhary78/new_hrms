import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/leave/data/models/leave_approve_model.dart';
import 'leave_approve_actions.dart';

class LeaveApproveCard extends StatefulWidget {
  final ManagerLeaveRequest request;
  final bool isPending;
  final Function(String, String, String?, List<String>?)? onApprove;
  final Function(String, String?)? onReject;

  const LeaveApproveCard({
    super.key,
    required this.request,
    required this.isPending,
    this.onApprove,
    this.onReject,
  });

  @override
  State<LeaveApproveCard> createState() => _LeaveApproveCardState();
}

class _LeaveApproveCardState extends State<LeaveApproveCard> {
  bool expanded = false;
  bool get canTakeAction {
    final s = widget.request.status.toLowerCase();

    return widget.isPending && (s == "pending" || s == "revocationrequested");
  }

  String formatDays(double days) {
    if (days == days.toInt()) return days.toInt().toString();
    return days.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.request;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final cardRadius = isIOS ? 14.0 : AppRadius.lg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: expanded
              ? scheme.primary.withOpacity(0.4)
              : scheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(isIOS ? 0.035 : 0.05),
            blurRadius: isIOS ? 6 : 8,
            offset: Offset(0, isIOS ? 2 : 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  r.employeeName.isNotEmpty
                      ? r.employeeName[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.employeeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.leaveType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              _statusChip(r.status, scheme),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          /// DATE ROW
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                "${_format(r.startDate)} → ${_format(r.endDate)}",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  "${formatDays(r.days)} day${r.days > 1 ? 's' : ''}",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),

          if (r.isHalfDay) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.timelapse, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  "Half Day (${r.halfDayPart ?? ''})",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],

          if (r.designation.isNotEmpty || r.department.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${r.designation} • ${r.department}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              children: [
                Text(
                  expanded ? "Hide details" : "View details",
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: scheme.primary,
                ),
              ],
            ),
          ),

          if (expanded) ...[
            const SizedBox(height: AppSpacing.sm),

            if (r.reason.isNotEmpty)
              Text(
                "Reason: ${r.reason}",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (r.status == "RevocationRequested" && r.revocationReason != null)
              Text(
                "Revoke Reason: ${r.revocationReason}",
                style: TextStyle(color: Colors.orange),
              ),

            const SizedBox(height: AppSpacing.sm),

            if (canTakeAction)
              LeaveApproveActions(
                request: r,
                onApprove: widget.onApprove!,
                onReject: widget.onReject!,
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status, ColorScheme scheme) {
    Color color;

    switch (status.toLowerCase()) {
      case "approved":
        color = scheme.primary;
        break;
      case "rejected":
        color = scheme.error;
        break;
      case "pending":
        color = scheme.tertiary;
        break;
      case "revocationrequested":
        color = Colors.orange;
        break;
      default:
        color = scheme.outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        displayStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _format(String date) {
    return DateFormat("dd MMM yyyy").format(DateTime.parse(date));
  }

  String displayStatus(String status) {
    if (status == "RevocationRequested") return "REVOKE REQUEST";
    return status.toUpperCase();
  }
}
