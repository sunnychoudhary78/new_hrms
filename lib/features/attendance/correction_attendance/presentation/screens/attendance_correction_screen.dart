import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/attendance_requests_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_filter_tabs.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../widgets/correction_stats.dart';
import '../widgets/correction_section.dart';

class AttendanceCorrectionScreen extends ConsumerStatefulWidget {
  const AttendanceCorrectionScreen({super.key});

  @override
  ConsumerState<AttendanceCorrectionScreen> createState() =>
      _AttendanceCorrectionScreenState();
}

class _AttendanceCorrectionScreenState
    extends ConsumerState<AttendanceCorrectionScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(attendanceRequestsProvider.notifier).fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(attendanceRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppAppBar(title: "Correct Attendance", showBack: false),
      drawer: const AppDrawer(),
      body: stateAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.heroStart),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (state) {
          final filtered = state.statusFilter == "ALL"
              ? state.requests
              : state.requests
                    .where((e) => e.status == state.statusFilter)
                    .toList();
          final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

          return RefreshIndicator(
            color: AppColors.heroStart,
            onRefresh: () async {
              await ref
                  .read(attendanceRequestsProvider.notifier)
                  .fetchRequests();
            },
            child: ListView(
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                PremiumFeatureHeader(
                  icon: Icons.fact_check_outlined,
                  title: 'Attendance correction requests',
                  subtitle:
                      'Review pending corrections and remote work requests from your team.',
                ),

                CorrectionStats(requests: state.requests),

                SizedBox(height: AppSpacing.lg),

                const AttendanceFilterTabs(),

                SizedBox(height: AppSpacing.md),

                Text(
                  "${filtered.length} requests",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                if (filtered.isEmpty)
                  _EmptyState(status: state.statusFilter)
                else
                  CorrectionSection(requests: filtered),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    String message;

    switch (status) {
      case "PENDING":
        message = "All pending requests are cleared.";
        break;
      case "APPROVED":
        message = "No approved requests yet";
        break;
      case "REJECTED":
        message = "No rejected requests";
        break;
      default:
        message = "No requests found";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: PremiumEmptyState(
        icon: Icons.inbox_rounded,
        title: 'No requests',
        subtitle: message,
      ),
    );
  }
}
