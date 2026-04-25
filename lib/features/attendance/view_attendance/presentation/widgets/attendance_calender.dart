import 'package:flutter/material.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/utils/attendance_status_color.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final List<AttendanceAggregate> aggregates;
  final Function(DateTime) onMonthChange;
  final ValueChanged<DateTime> onDaySelected;

  const AttendanceCalendar({
    super.key,
    required this.focusedDay,
    required this.aggregates,
    required this.onMonthChange,
    required this.onDaySelected,
    this.selectedDay,
  });

  /// ✅ Consistent key formatter
  String _keyOf(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    /// ✅ O(1) lookup instead of O(n)
    final Map<String, AttendanceAggregate> map = {
      for (var a in aggregates) _keyOf(a.date): a,
    };

    /// ✅ Safe + smart fallback
    AttendanceAggregate forDay(DateTime d) {
      final key = _keyOf(d);

      return map[key] ??
          AttendanceAggregate(
            date: d,
            status: d.isAfter(DateTime.now()) ? 'none' : 'absent',
          );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TableCalendar(
          focusedDay: focusedDay,
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2026, 12, 31),
          onPageChanged: onMonthChange,
          selectedDayPredicate: (d) => isSameDay(d, selectedDay),
          onDaySelected: (selected, _) => onDaySelected(selected),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (_, d, __) {
              final status = forDay(d).status;
              final color = AttendanceStatusColor.fromStatus(context, status);

              return _cell(context, d, color);
            },
            todayBuilder: (_, d, __) {
              final status = forDay(d).status;
              final color = AttendanceStatusColor.fromStatus(context, status);

              return _cell(context, d, color, isToday: true);
            },
            selectedBuilder: (_, d, __) {
              final status = forDay(d).status;
              final color = AttendanceStatusColor.fromStatus(context, status);

              return _cell(context, d, color, isSelected: true);
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime d,
    Color color, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: scheme.primary, width: 2)
            : isToday
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
      ),
      child: Text(
        "${d.day}",
        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    );
  }
}
