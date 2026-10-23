import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import '../../data/models/leave_details_model.dart';

class LeaveTimelineWidget extends StatelessWidget {
  final List<LeaveHistory> histories;

  const LeaveTimelineWidget({super.key, required this.histories});

  @override
  Widget build(BuildContext context) {
    if (histories.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle('Timeline'),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(histories.length, (index) {
          final history = histories[index];
          final isLast = index == histories.length - 1;
          final color = _colorForAction(history.action);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 52,
                      color: AppColors.border,
                    ),
                ],
              ),
              SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.action,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.title,
                        ),
                      ),
                      if (history.actorName != null)
                        Text(
                          'by ${history.actorName}',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      if (history.at != null)
                        Text(
                          _formatDate(history.at!),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      if (history.comment != null &&
                          history.comment!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            history.comment!,
                            style: TextStyle(
                              color: AppColors.title,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Color _colorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'submitted':
        return AppColors.info;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'revoked':
        return AppColors.draft;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
