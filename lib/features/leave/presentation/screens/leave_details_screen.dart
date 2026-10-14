import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

import '../../data/models/leave_details_model.dart';
import '../providers/leave_details_provider.dart';
import '../widgets/leave_timeline_widget.dart';

class LeaveDetailsScreen extends ConsumerWidget {
  final String leaveRequestId;

  const LeaveDetailsScreen({super.key, required this.leaveRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveAsync = ref.watch(leaveDetailsProvider(leaveRequestId));
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: 'Leave Details'),
      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: appScreenPadding,
          child: AppSectionCard(
            child: Text(
              'Failed to load leave\n$e',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
        data: (LeaveDetails leave) {
          final scrollPhysics = isIOS
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const ClampingScrollPhysics();

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: scrollPhysics,
            padding: appScreenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeroBanner(
                  icon: Icons.event_available_rounded,
                  title: leave.leaveType ?? 'Leave Request',
                  message: '${leave.days} day(s) · ${leave.startDate} → ${leave.endDate}',
                  trailing: AppStatusPill(label: leave.status),
                ),
                const SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle('Request details'),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Leave type',
                        value: leave.leaveType ?? '-',
                      ),
                      _DetailRow(
                        icon: Icons.timelapse_outlined,
                        label: 'Days',
                        value: '${leave.days}',
                      ),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'From',
                        value: leave.startDate,
                      ),
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'To',
                        value: leave.endDate,
                      ),
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Manager',
                        value: leave.managerName ?? '-',
                      ),
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Reason',
                        value: leave.reason ?? '-',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (leave.histories.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppSectionCard(
                    child: LeaveTimelineWidget(histories: leave.histories),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
