import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/correction_attendance/presentation/dialogs/request_correction_dialog.dart';
import 'package:lms/features/attendance/view_attendance/presentation/providers/view_attendance_provider.dart';
import 'package:lms/features/attendance/view_attendance/presentation/widgets/view_attendance_header.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';

import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';

import 'package:lms/features/dashboard/data/models/attendance_day_data.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';

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

  ////////////////////////////////////////////////////////////////
  /// BUILD ATTENDANCE MAP FROM AGGREGATES + SESSIONS
  ////////////////////////////////////////////////////////////////

  Map<String, AttendanceDayData> _buildAttendanceMap(
    List aggregates,
    List<AttendanceSession> sessions,
  ) {
    final Map<String, List<AttendanceSession>> sessionsByDate = {};

    for (final s in sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.checkInTime);

      sessionsByDate.putIfAbsent(key, () => []);
      sessionsByDate[key]!.add(s);
    }

    final Map<String, AttendanceDayData> map = {};

    for (final agg in aggregates) {
      final key = DateFormat('yyyy-MM-dd').format(agg.date);

      final daySessions = sessionsByDate[key] ?? [];

      final totalMinutes = daySessions.fold<int>(
        0,
        (sum, s) => sum + (s.durationMinutes),
      );

      map[key] = AttendanceDayData(
        date: key,
        status: agg.status,
        totalMinutes: totalMinutes,
        sessions: daySessions.map((s) {
          return AttendanceSessionData(
            checkIn: s.checkInTime,
            checkOut: s.checkOutTime,
            durationMinutes: s.durationMinutes,
            source: s.source,
            checkInSelfie: s.checkInSelfie,
            checkOutSelfie: s.checkOutSelfie,
            lat: s.lat,
            lng: s.lng,
          );
        }).toList(),
      );
    }

    ////////////////////////////////////////////////////////////
    /// GENERATE ABSENT DAYS
    ////////////////////////////////////////////////////////////

    final startOfMonth = DateTime(focused.year, focused.month, 1);
    final endOfMonth = DateTime(focused.year, focused.month + 1, 0);

    for (
      DateTime d = startOfMonth;
      !d.isAfter(endOfMonth);
      d = d.add(const Duration(days: 1))
    ) {
      final key = DateFormat('yyyy-MM-dd').format(d);

      // already has data
      if (map.containsKey(key)) continue;

      // skip future days
      if (d.isAfter(DateTime.now())) continue;

      // skip weekends if your company treats them as holiday
      if (d.weekday == DateTime.sunday) continue;

      map[key] = AttendanceDayData(
        date: key,
        status: "Absent",
        totalMinutes: 0,
        sessions: [],
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

          if (summary == null) {
            return Center(
              child: Text(
                "No summary available",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }

          ////////////////////////////////////////////////////////////
          /// BUILD MAP FOR CALENDAR
          ////////////////////////////////////////////////////////////

          final attendanceMap = _buildAttendanceMap(
            state.aggregates,
            state.sessions,
          );

          ////////////////////////////////////////////////////////////

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(viewAttendanceProvider.notifier)
                  .changeMonth(focused);
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

                    child: AttendanceSummaryGrid(summary: summary),
                  ),

                  const SizedBox(height: 28),

                  ////////////////////////////////////////////////////////
                  /// PIE CHART
                  ////////////////////////////////////////////////////////
                  _Section(
                    title: "Attendance Breakdown",

                    child: AttendancePieChart(
                      present: summary.workingDays,

                      absent: summary.absentDays,

                      late: summary.lateDays,

                      leave: summary.totalLeaves,
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
