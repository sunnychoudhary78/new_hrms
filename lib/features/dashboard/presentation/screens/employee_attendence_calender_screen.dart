import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/attendance/view_attendance/utils/calendar_type_style.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';
import 'package:lms/shared/widgets/attendance_month_summary.dart';
import '../../data/models/attendance_day_data.dart';
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

  ////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: AppColors.bg,

      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),

        data: (attendanceMap) {
          ////////////////////////////////////////////////////////////

          String? resolveStatus(DateTime day) {
            final key = DateFormat('yyyy-MM-dd').format(day);
            return attendanceMap[key]?.calendarStatus;
          }

          String? resolveTypeLabel(DateTime day) {
            final key = DateFormat('yyyy-MM-dd').format(day);
            return attendanceMap[key]?.calendarCellLabel;
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmployeeHeader(employee: widget.employee),

                const SizedBox(height: AppSpacing.lg),

                summaryAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                  data: (_) => PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: "Month summary",
                          subtitle:
                              "Counts for the selected month from attendance records.",
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AttendanceMonthSummary(counts: counts),
                        _LeaveTypeList(summary: summary),
                        _HolidayNameList(attendanceMap: attendanceMap),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ////////////////////////////////////////////////////
                /// CALENDAR
                ////////////////////////////////////////////////////
                AttendanceCalendarWidget(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  statusResolver: resolveStatus,
                  typeLabelResolver: resolveTypeLabel,
                  typeColorResolver: (day) {
                    final key = DateFormat('yyyy-MM-dd').format(day);
                    return attendanceMap[key]?.calendarCellColor;
                  },

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

class _LeaveTypeList extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _LeaveTypeList({required this.summary});

  @override
  Widget build(BuildContext context) {
    final raw = summary['leaveBreakdown'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final type = (item['type'] ?? '').toString().trim();
      if (type.isEmpty) continue;
      final days = item['days'];
      final daysLabel = days == null ? '' : ' · $days';
      final color = CalendarTypeStyle.leaveColor(type);
      final code = CalendarTypeStyle.leaveCode(type);
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$code$daysLabel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Leave Types",
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _HolidayNameList extends StatelessWidget {
  final Map<String, AttendanceDayData> attendanceMap;

  const _HolidayNameList({required this.attendanceMap});

  @override
  Widget build(BuildContext context) {
    final entries = attendanceMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final labels = <String>[];
    for (final entry in entries) {
      final day = entry.value;
      final isHoliday =
          day.status.trim().toLowerCase() == 'holiday' ||
          day.holidayName != null;
      if (!isHoliday) continue;

      final name = day.holidayLabel;
      final displayName = name ?? 'Holiday';
      final parsed = DateTime.tryParse(entry.key);
      final when = parsed == null
          ? entry.key
          : DateFormat('dd MMM').format(parsed.toLocal());
      labels.add('$when · $displayName');
    }

    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Holiday Calendar",
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in labels)
                Builder(
                  builder: (context) {
                    final color = CalendarTypeStyle.holidayColor(label);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  final TeamEmployee employee;

  const _EmployeeHeader({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppColors.heroDecoration(radius: AppRadius.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : "?",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.employeeId,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.88),
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
