import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/correction_attendance/presentation/dialogs/request_correction_dialog.dart';
import 'package:lms/features/attendance/view_attendance/presentation/providers/view_attendance_provider.dart';
import 'package:lms/features/attendance/view_attendance/presentation/widgets/view_attendance_header.dart';
import 'package:lms/features/dashboard/presentation/providers/team_attendance_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';

import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';

import 'package:lms/features/dashboard/data/models/attendance_day_data.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';

import '../widgets/attendance_summary_grid.dart';
import '../widgets/attendance_pie_chart.dart';

class ViewAttendanceScreen extends ConsumerStatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  ConsumerState<ViewAttendanceScreen> createState() =>
      _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends ConsumerState<ViewAttendanceScreen> {
  DateTime focused = DateTime.now();
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(viewAttendanceProvider);

      ref.invalidate(
        employeeAttendanceProvider(
          AttendanceParams(
            userId: "",
            month: focused, // ✅ FIXED
          ),
        ),
      );
    });
  }

  ////////////////////////////////////////////////////////////////
  /// BUILD ATTENDANCE MAP FROM AGGREGATES + SESSIONS
  ////////////////////////////////////////////////////////////////

  AttendanceDayData? _sessionDataForDay(
    DateTime day,
    Map<String, AttendanceDayData> sessionMap,
  ) {
    final directKey = DateFormat('yyyy-MM-dd').format(day);
    final direct = sessionMap[directKey];
    if (direct != null) return direct;

    for (final entry in sessionMap.entries) {
      final parsed = DateTime.tryParse(entry.key);
      if (parsed != null && DateUtils.isSameDay(parsed.toLocal(), day)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Align [AttendanceSummary] with calendar when API still counts today as
  /// absent but sessions prove the user checked in.
  AttendanceSummary _adjustedSummary({
    required AttendanceSummary summary,
    required List<AttendanceAggregate> aggregates,
    required Map<String, AttendanceDayData> sessionMap,
  }) {
    final today = DateTime.now();

    AttendanceAggregate? todayAgg;

    for (final a in aggregates) {
      if (DateUtils.isSameDay(a.date, today)) {
        todayAgg = a;
        break;
      }
    }

    if (todayAgg == null || todayAgg.status != 'absent') return summary;

    final sessions =
        _sessionDataForDay(todayAgg.date, sessionMap)?.sessions ?? [];

    if (!sessions.any((s) => s.checkIn != null)) return summary;

    return AttendanceSummary(
      workingDays: summary.workingDays + 1,
      lateDays: summary.lateDays,
      totalLeaves: summary.totalLeaves,
      absentDays: summary.absentDays > 0 ? summary.absentDays - 1 : 0,
      payableDays: summary.payableDays,
      totalMinutes: summary.totalMinutes,
      expectedWorkingHours: summary.expectedWorkingHours,
    );
  }

  Map<String, AttendanceDayData> _buildAttendanceMap(
    List aggregates,
    Map<String, AttendanceDayData> sessionMap,
  ) {
    final Map<String, AttendanceDayData> map = {};

    for (final agg in aggregates) {
      final key = DateFormat('yyyy-MM-dd').format(agg.date);
      final sessionData = _sessionDataForDay(agg.date, sessionMap);
      final sessions = sessionData?.sessions ?? [];

      map[key] = AttendanceDayData(
        date: key,
        status: AttendanceDayData.resolveStatusWithSessions(agg.status, sessions),
        totalMinutes: sessionData?.totalMinutes ?? 0,
        sessions: sessions,
      );
    }

    return map;
  }

  ////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final async = ref.watch(viewAttendanceProvider);

    return Scaffold(
      appBar: const AppAppBar(title: "View Attendance"),
      drawer: const AppDrawer(),

      backgroundColor: scheme.surfaceContainerLowest,

      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: scheme.primary)),

        error: (e, _) => Center(
          child: Text(e.toString(), style: TextStyle(color: scheme.error)),
        ),

        data: (state) {
          final summary = state.summary;

          ////////////////////////////////////////////////////////////
          /// BUILD MAP FOR CALENDAR
          ////////////////////////////////////////////////////////////
          final sessionAsync = ref.watch(
            employeeAttendanceProvider(
              AttendanceParams(
                userId: "", // keep empty for employee
                month: focused,
              ),
            ),
          );

          final attendanceMap = sessionAsync.when(
            data: (sessionMap) => _buildAttendanceMap(state.days, sessionMap),
            loading: () => <String, AttendanceDayData>{},
            error: (_, __) => <String, AttendanceDayData>{},
          );

          final displaySummary = attendanceMap.isEmpty
              ? summary
              : _adjustedSummary(
                  summary: summary,
                  aggregates: state.days,
                  sessionMap: attendanceMap,
                );

          ////////////////////////////////////////////////////////////

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(viewAttendanceProvider.notifier)
                  .changeMonth(focused);

              ref.invalidate(
                employeeAttendanceProvider(
                  AttendanceParams(userId: "", month: focused),
                ),
              );
            },

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const ViewAttendanceHeader(),

                  const SizedBox(height: 24),

                  ////////////////////////////////////////////////////////
                  /// PREMIUM CALENDAR
                  ////////////////////////////////////////////////////////
                  _Section(
                    title: "Attendance Calendar",

                    child: AttendanceCalendarWidget(
                      focusedDay: focused,

                      selectedDay: selectedDay,

                      ////////////////////////////////////////////////////
                      /// STATUS RESOLVER
                      ////////////////////////////////////////////////////
                      statusResolver: (day) {
                        final key = DateFormat('yyyy-MM-dd').format(day);
                        return attendanceMap[key]?.status;
                      },

                      hasSelfie: (day) {
                        final key = DateFormat('yyyy-MM-dd').format(day);
                        final data = attendanceMap[key];

                        if (data == null) return false;

                        return data.sessions.any(
                          (s) =>
                              s.checkInSelfie != null ||
                              s.checkOutSelfie != null,
                        );
                      },

                      hasLocation: (day) {
                        final key = DateFormat('yyyy-MM-dd').format(day);
                        final data = attendanceMap[key];

                        if (data == null) return false;

                        return data.sessions.any(
                          (s) => s.lat != null && s.lng != null,
                        );
                      },
                      ////////////////////////////////////////////////////
                      /// DAY SELECTED
                      ////////////////////////////////////////////////////
                      onDaySelected: (selected, focusedDay) {
                        setState(() {
                          selectedDay = selected;
                          focused = focusedDay;
                        });

                        final key = DateFormat('yyyy-MM-dd').format(selected);

                        final dayData = attendanceMap[key];

                        AttendanceDayDetailBottomSheet.show(
                          context,

                          date: selected,

                          data: dayData,
                        );
                      },

                      ////////////////////////////////////////////////////
                      /// MONTH CHANGE
                      ////////////////////////////////////////////////////
                      onPageChanged: (d) {
                        setState(() {
                          focused = d;
                        });

                        ref
                            .read(viewAttendanceProvider.notifier)
                            .changeMonth(d);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  ////////////////////////////////////////////////////////
                  /// CORRECTION BUTTON
                  ////////////////////////////////////////////////////////
                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_calendar_rounded),

                      label: const Text("Request Attendance Correction"),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,

                        foregroundColor: scheme.onPrimary,

                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      onPressed: () {
                        showRequestCorrectionDialog(
                          context: context,

                          selectedDate: selectedDay ?? DateTime.now(),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  ////////////////////////////////////////////////////////
                  /// SUMMARY GRID
                  ////////////////////////////////////////////////////////
                  _Section(
                    title: "Monthly Summary",

                    child: AttendanceSummaryGrid(summary: displaySummary),
                  ),

                  const SizedBox(height: 28),

                  ////////////////////////////////////////////////////////
                  /// PIE CHART
                  ////////////////////////////////////////////////////////
                  _Section(
                    title: "Attendance Breakdown",

                    child: AttendancePieChart(
                      present: displaySummary.workingDays,

                      absent: displaySummary.absentDays,

                      late: displaySummary.lateDays,

                      leave: displaySummary.totalLeaves,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// SECTION CARD
//////////////////////////////////////////////////////////////

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,

      color: scheme.surface,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 12),

            child,
          ],
        ),
      ),
    );
  }
}
