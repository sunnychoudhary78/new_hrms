import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/attendance_requests_provider.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/widgets/section_header.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
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
                /// STATS
                CorrectionStats(requests: state.requests),

                const SizedBox(height: AppSpacing.lg),

                /// FILTER HEADER + MENU
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    /// HEADER
                    const Expanded(
                      child: SectionHeader(
                        title: "Filter by status",
                        icon: Icons.filter_alt_rounded,
                      ),
                    ),

                    /// FILTER BUTTON
                    PopupMenuButton<String>(
                      tooltip: "Filter: ${state.statusFilter}",
                      onSelected: (value) {
                        ref
                            .read(attendanceRequestsProvider.notifier)
                            .changeStatus(value);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: "PENDING", child: Text("Pending")),
                        PopupMenuItem(
                          value: "APPROVED",
                          child: Text("Approved"),
                        ),
                        PopupMenuItem(
                          value: "REJECTED",
                          child: Text("Rejected"),
                        ),
                        PopupMenuItem(value: "ALL", child: Text("All")),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              state.statusFilter,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                /// CORRECTIONS HEADER
                const SectionHeader(
                  title: "Attendance corrections",
                  icon: Icons.access_time_rounded,
                ),

                const SizedBox(height: AppSpacing.sm),

                /// CORRECTION SECTION
                CorrectionSection(
                  title: "Attendance Corrections",
                  subtitle: "Missed punches & edits",
                  type: "CORRECTION",
                  requests: state.requests,
                ),

                const SizedBox(height: AppSpacing.xl),

                /// REMOTE WORK HEADER
                const SectionHeader(
                  title: "Remote work requests",
                  icon: Icons.home_work_rounded,
                ),

                const SizedBox(height: AppSpacing.sm),

                /// REMOTE SECTION
                CorrectionSection(
                  title: "Remote Work Requests",
                  subtitle: "WFH & remote approvals",
                  type: "REMOTE",
                  requests: state.requests,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
