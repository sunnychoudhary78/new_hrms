import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/attendance_requests_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_filter_tabs.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final stateAsync = ref.watch(attendanceRequestsProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(title: "Correct Attendance"),
      drawer: const AppDrawer(),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (state) {
          /// 🔥 FILTERED LIST (IMPORTANT)
          final filtered = state.statusFilter == "ALL"
              ? state.requests
              : state.requests
                    .where((e) => e.status == state.statusFilter)
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(attendanceRequestsProvider.notifier)
                  .fetchRequests();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                /// 📊 STATS
                CorrectionStats(requests: state.requests),

                const SizedBox(height: AppSpacing.lg),

                /// 🔘 FILTER TABS
                const AttendanceFilterTabs(),

                const SizedBox(height: AppSpacing.md),

                /// 📌 COUNT TEXT (nice polish)
                Text(
                  "${filtered.length} requests",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                /// 📋 LIST
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

/// 🔥 EMPTY STATE (important polish)
class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String message;

    switch (status) {
      case "PENDING":
        message = "🎉 All caught up!";
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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withOpacity(.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
