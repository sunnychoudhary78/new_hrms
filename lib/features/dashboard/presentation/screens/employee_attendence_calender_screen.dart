import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';
import 'package:lms/shared/widgets/attendance_month_summary.dart';
import '../../data/models/team_dashboard_model.dart';
import '../providers/team_attendance_provider.dart';

class EmployeeAttendanceCalendarScreen extends ConsumerStatefulWidget {
  final TeamEmployee employee;
  final DateTime? highlightDate;

  const EmployeeAttendanceCalendarScreen({
    super.key,
    required this.employee,
    this.highlightDate,
  });

  @override
  ConsumerState<EmployeeAttendanceCalendarScreen> createState() =>
      _EmployeeAttendanceCalendarScreenState();
}

class _EmployeeAttendanceCalendarScreenState
    extends ConsumerState<EmployeeAttendanceCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(employeeAttendanceProvider);
      ref.invalidate(employeeAttendanceSummaryProvider); // ✅ NEW
    });

    _selectedDay = widget.highlightDate;
    final initial = widget.highlightDate ?? DateTime.now();
    _focusedDay = DateTime(initial.year, initial.month);
  }

  bool _isFutureMonth(DateTime day) {
    final now = DateTime.now();
    return day.year > now.year ||
        (day.year == now.year && day.month > now.month);
  }

  ////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final params = AttendanceParams(
      userId: widget.employee.userId,
      month: DateTime(_focusedDay.year, _focusedDay.month),
    );

    final attendanceAsync = ref.watch(employeeAttendanceProvider(params));
    final summaryAsync = ref.watch(
      employeeAttendanceSummaryProvider(params),
    ); // ✅ NEW

    return Scaffold(
      appBar: AppAppBar(title: "View Attendance"),
      backgroundColor: scheme.surfaceContainerLowest,

      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),

        data: (attendanceMap) {
          ////////////////////////////////////////////////////////////

          String? resolveStatus(DateTime day) {
            final key = DateFormat('yyyy-MM-dd').format(day);
            return attendanceMap[key]?.status;
          }

          ////////////////////////////////////////////////////////////
          // ✅ USE BACKEND SUMMARY (FIX)
          ////////////////////////////////////////////////////////////

          final summary = summaryAsync.value ?? {};

          final counts = <String, int>{
            "On-Time": (summary["workingDays"] as num?)?.toInt() ?? 0,
            "Late": (summary["lateDays"] as num?)?.toInt() ?? 0,
            "Absent": (summary["absentDays"] as num?)?.toInt() ?? 0,
            "Holiday": (summary["totalHolidays"] as num?)?.toInt() ?? 0,
            "On-Leave": (summary["totalLeaves"] as num?)?.toInt() ?? 0,
          };

          ////////////////////////////////////////////////////////////

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: defaultTargetPlatform == TargetPlatform.iOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmployeeHeader(employee: widget.employee),

                const SizedBox(height: 24),

                ////////////////////////////////////////////////////
                /// ✅ SUMMARY (FIXED)
                ////////////////////////////////////////////////////
                summaryAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                  data: (_) => AttendanceMonthSummary(counts: counts),
                ),

                const SizedBox(height: 24),

                ////////////////////////////////////////////////////
                /// CALENDAR
                ////////////////////////////////////////////////////
                AttendanceCalendarWidget(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  statusResolver: resolveStatus,

                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });

                    final key = DateFormat('yyyy-MM-dd').format(selectedDay);
                    final dayData = attendanceMap[key];

                    AttendanceDayDetailBottomSheet.show(
                      context,
                      date: selectedDay,
                      data: dayData,
                    );
                  },

                  onPageChanged: (focusedDay) {
                    final normalized = DateTime(
                      focusedDay.year,
                      focusedDay.month,
                    );

                    if (_isFutureMonth(normalized)) return;

                    if (_focusedDay.year == normalized.year &&
                        _focusedDay.month == normalized.month) {
                      return;
                    }

                    setState(() {
                      _focusedDay = normalized;
                    });

                    ////////////////////////////////////////////////////
                    /// 🔥 REFRESH ON MONTH CHANGE
                    ////////////////////////////////////////////////////
                    ref.invalidate(
                      employeeAttendanceProvider(
                        AttendanceParams(
                          userId: widget.employee.userId,
                          month: normalized,
                        ),
                      ),
                    );

                    ref.invalidate(
                      employeeAttendanceSummaryProvider(
                        AttendanceParams(
                          userId: widget.employee.userId,
                          month: normalized,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////////////

class _EmployeeHeader extends StatelessWidget {
  final TeamEmployee employee;

  const _EmployeeHeader({required this.employee});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isIOS ? 16 : 20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : "?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
