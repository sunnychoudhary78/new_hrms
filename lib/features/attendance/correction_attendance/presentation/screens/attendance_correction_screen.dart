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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primaryContainer,
                        scheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.fact_check_outlined,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Attendance correction requests",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                CorrectionStats(requests: state.requests),

                const SizedBox(height: AppSpacing.lg),

                const AttendanceFilterTabs(),

                const SizedBox(height: AppSpacing.md),

                Text(
                  "${filtered.length} requests",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;

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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 44, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
