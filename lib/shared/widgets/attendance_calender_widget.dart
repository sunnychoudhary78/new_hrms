import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

typedef AttendanceStatusResolver = String? Function(DateTime day);
typedef AttendanceBoolResolver = bool Function(DateTime day);

class AttendanceCalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final Function(DateTime focusedDay)? onPageChanged;
  final AttendanceStatusResolver statusResolver;
  final AttendanceBoolResolver? hasSelfie;
  final AttendanceBoolResolver? hasLocation;

  const AttendanceCalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.statusResolver,
    this.onPageChanged,
    this.hasSelfie,
    this.hasLocation,
  });

  /// Premium status colors
  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case "On-Time":
        return const Color(0xFF22C55E); // emerald
      case "Late":
        return const Color(0xFFF59E0B); // amber
      case "Absent":
        return const Color(0xFFEF4444); // red
      case "Holiday":
        return const Color(0xFF3B82F6); // blue
      case "On-Leave":
        return const Color(0xFFA855F7); // purple
      default:
        return scheme.outlineVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2035),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),

        onDaySelected: onDaySelected,

        onPageChanged: (day) {
          if (onPageChanged != null) {
            onPageChanged!(day);
          }
        },

        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: scheme.onSurfaceVariant,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
          ),
        ),

        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.error,
          ),
        ),

        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,

          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: 2),
          ),

          selectedDecoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),

          selectedTextStyle: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),

          defaultTextStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),

          weekendTextStyle: TextStyle(
            color: scheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),

        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) {
            final status = statusResolver(day);

            if (status == null) return null;

            final color = _statusColor(status, scheme);

            return _DayCell(
              day: day,
              color: color,
              scheme: scheme,
              hasSelfie: hasSelfie?.call(day) ?? false,
              hasLocation: hasLocation?.call(day) ?? false,
            );
          },

          todayBuilder: (context, day, _) {
            final status = statusResolver(day);

            return _TodayCell(
              day: day,
              status: status,
              scheme: scheme,
              statusColor: status != null ? _statusColor(status, scheme) : null,
            );
          },

          selectedBuilder: (context, day, _) {
            return Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "${day.day}",
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// DEFAULT DAY CELL
////////////////////////////////////////////////////////////////

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Color color;
  final ColorScheme scheme;
  final bool hasSelfie;
  final bool hasLocation;

  const _DayCell({
    required this.day,
    required this.color,
    required this.scheme,
    required this.hasSelfie,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(.22),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${day.day}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 12,
                ),
              ),

              if (hasSelfie || hasLocation) const SizedBox(height: 2),

              if (hasSelfie || hasLocation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasSelfie)
                      Icon(Icons.camera_alt, size: 8, color: color),

                    if (hasSelfie && hasLocation) const SizedBox(width: 2),

                    if (hasLocation)
                      Icon(Icons.location_pin, size: 8, color: color),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// TODAY CELL (Premium ring + dot)
////////////////////////////////////////////////////////////////

class _TodayCell extends StatelessWidget {
  final DateTime day;
  final String? status;
  final ColorScheme scheme;
  final Color? statusColor;

  const _TodayCell({
    required this.day,
    required this.status,
    required this.scheme,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: 2),
            ),
          ),
          Text(
            "${day.day}",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          if (statusColor != null)
            Positioned(
              bottom: 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
