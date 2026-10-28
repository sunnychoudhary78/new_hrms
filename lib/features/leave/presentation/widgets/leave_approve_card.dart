import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/leave/data/models/leave_approve_model.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
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

    return widget.isPending &&
        widget.onApprove != null &&
        widget.onReject != null &&
        (s == "pending" || s == "revocationrequested");
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
    final cardRadius = isIOS ? AppRadius.md + 2 : AppRadius.lg;
    final isRevoke = r.status == "RevocationRequested";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppColors.cardDecoration(
        highlighted: expanded,
        radius: cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.softBlueStart,
                child: Text(
                  r.employeeName.isNotEmpty
                      ? r.employeeName[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: AppColors.primary,
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

              AppStatusPill(label: r.status),
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
                  color: AppColors.softBlueStart,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  "${formatDays(r.days)} day${r.days > 1 ? 's' : ''}",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
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

          /// Revocation reason is important for the decision — always visible
          if (isRevoke && r.revocationReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Revoke reason: ${r.revocationReason}",
              style: const TextStyle(color: AppColors.statusDeepOrange),
            ),
          ],

          /// ACTIONS — visible right on the card, no need to expand
          if (canTakeAction) ...[
            const SizedBox(height: AppSpacing.md),
            LeaveApproveActions(
              request: r,
              onApprove: widget.onApprove!,
              onReject: widget.onReject!,
            ),
          ],

          /// DETAILS (reason only)
          if (r.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => expanded = !expanded),
              child: Row(
                children: [
                  Text(
                    expanded ? "Hide reason" : "View reason",
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
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _format(String date) {
    return DateFormat("dd MMM yyyy").format(DateTime.parse(date));
  }
}