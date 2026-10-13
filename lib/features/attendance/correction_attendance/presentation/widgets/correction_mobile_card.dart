import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/dialogs/review_request_dialog.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../../data/models/attendance_request_model.dart';
import 'user_cell.dart';

class RequestCard extends StatelessWidget {
  final AttendanceRequest item;

  const RequestCard({super.key, required this.item});

  String formatTime(String? iso) => formatIsoToLocalTime(iso);

  Color _statusColor() {
    switch (item.status) {
      case "APPROVED":
        return AppColors.success;
      case "REJECTED":
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  String _typeLabel() {
    if (item.isRemote) return "Remote";
    return "Correction";
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final innerR = BorderRadius.circular(isIOS ? 10 : AppRadius.sm);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppColors.cardDecoration(radius: AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumStatusPill(
                label: _typeLabel(),
                color: AppColors.heroStart,
              ),
              const Spacer(),
              PremiumStatusPill(
                label: item.status,
                color: statusColor,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          UserCell(name: item.userName, image: item.userImage),

          const SizedBox(height: AppSpacing.sm),

          Text(
            item.reason ?? "—",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.title,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (item.isCorrection || item.isRemote)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: innerR,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        "Original",
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${formatTime(item.originalCheckIn)} → ${formatTime(item.originalCheckOut)}",
                        style: const TextStyle(
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        "Proposed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.title,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${formatTime(item.proposedCheckIn)} → ${formatTime(item.proposedCheckOut)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.title,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          if (item.status == "PENDING")
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                      foregroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () {
                      showReviewDialog(context: context, req: item);
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("Reject"),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.heroStart,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () {
                      showReviewDialog(context: context, req: item);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Approve"),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  showReviewDialog(context: context, req: item);
                },
                child: const Text("View details"),
              ),
            ),
        ],
      ),
    );
  }
}
