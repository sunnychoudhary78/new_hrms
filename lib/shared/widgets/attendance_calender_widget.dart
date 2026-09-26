import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/attendance/view_attendance/utils/calendar_type_style.dart';
import 'package:table_calendar/table_calendar.dart';

typedef AttendanceStatusResolver = String? Function(DateTime day);
typedef AttendanceBoolResolver = bool Function(DateTime day);
typedef AttendanceLabelResolver = String? Function(DateTime day);
typedef AttendanceColorResolver = Color? Function(DateTime day);

class AttendanceCalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final Function(DateTime focusedDay)? onPageChanged;
  final AttendanceStatusResolver statusResolver;
  final AttendanceLabelResolver? typeLabelResolver;
  final AttendanceColorResolver? typeColorResolver;
  final AttendanceBoolResolver? hasSelfie;
  final AttendanceBoolResolver? hasLocation;
  final List<({String label, Color color})> typeLegend;

  const AttendanceCalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.statusResolver,
    this.typeLabelResolver,
    this.typeColorResolver,
    this.onPageChanged,
    this.hasSelfie,
    this.hasLocation,
    this.typeLegend = const [],
  });

  /// Premium status colors
  Color _statusColor(String status, ColorScheme scheme) {
    final normalized = status.trim().toLowerCase();

    switch (normalized) {
      case "on-time":
      case "ontime":
      case "present":
        return const Color(0xFF22C55E); // emerald
      case "late":
        return const Color(0xFFF59E0B); // amber
      case "absent":
        return const Color(0xFFEF4444); // red
      case "holiday":
        return CalendarTypeStyle.holidayCategory;
      case "weekoff":
      case "week-off":
      case "week off":
        return const Color(0xFF8B5CF6); // violet
      case "on-leave":
      case "on leave":
      case "leave":
        return CalendarTypeStyle.leaveCategory;
      default:
        return scheme.outlineVariant;
    }
  }

  Color _cellColor(DateTime day, String? status, ColorScheme scheme) {
    return typeColorResolver?.call(day) ??
        (status != null ? _statusColor(status, scheme) : scheme.outlineVariant);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final outerRadius = BorderRadius.circular(isIOS ? 16 : 24);
    final blur = isIOS ? 12.0 : 24.0;
    final shadowAlpha = isIOS ? 0.04 : 0.06;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: outerRadius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: shadowAlpha),
            blurRadius: blur,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime.now(), // prevents future navigation
        focusedDay: DateTime(focusedDay.year, focusedDay.month, 1),
        rowHeight: 54,
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

            final color = _cellColor(day, status, scheme);

            return _DayCell(
              day: day,
              color: color,
              scheme: scheme,
              hasSelfie: hasSelfie?.call(day) ?? false,
              hasLocation: hasLocation?.call(day) ?? false,
              typeLabel: typeLabelResolver?.call(day),
            );
          },

          todayBuilder: (context, day, _) {
            final status = statusResolver(day);

            return _TodayCell(
              day: day,
              status: status,
              scheme: scheme,
              statusColor: _cellColor(day, status, scheme),
              typeLabel: typeLabelResolver?.call(day),
            );
          },

          selectedBuilder: (context, day, _) {
            final status = statusResolver(day);

            return _SelectedDayCell(
              day: day,
              scheme: scheme,
              typeLabel: typeLabelResolver?.call(day),
              labelColor: _cellColor(day, status, scheme),
            );
          },
        ),
          ),
          const SizedBox(height: 10),
          _StatusLegend(typeLegend: typeLegend),
        ],
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
  final String? typeLabel;

  const _DayCell({
    required this.day,
    required this.color,
    required this.scheme,
    required this.hasSelfie,
    required this.hasLocation,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = typeLabel?.trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .22),
                ),
              ),
              Text(
                "${day.day}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 12,
                ),
              ),
              if (hasSelfie || hasLocation)
                Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasSelfie)
                        Icon(Icons.camera_alt, size: 7, color: color),
                      if (hasSelfie && hasLocation) const SizedBox(width: 1),
                      if (hasLocation)
                        Icon(Icons.location_pin, size: 7, color: color),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (label != null && label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
      ],
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
  final String? typeLabel;

  const _TodayCell({
    required this.day,
    required this.status,
    required this.scheme,
    this.statusColor,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = typeLabel?.trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
              Text(
                "${day.day}",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: scheme.primary,
                ),
              ),
              if (statusColor != null)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (label != null && label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w800,
                  color: statusColor ?? scheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedDayCell extends StatelessWidget {
  final DateTime day;
  final ColorScheme scheme;
  final String? typeLabel;
  final Color labelColor;

  const _SelectedDayCell({
    required this.day,
    required this.scheme,
    required this.labelColor,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = typeLabel?.trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            "${day.day}",
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        if (label != null && label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final List<({String label, Color color})> typeLegend;

  const _StatusLegend({this.typeLegend = const []});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        const _LegendItem(label: "Present", color: Color(0xFF22C55E)),
        const _LegendItem(label: "Late", color: Color(0xFFF59E0B)),
        const _LegendItem(label: "Absent", color: Color(0xFFEF4444)),
        const _LegendItem(label: "Leave", color: CalendarTypeStyle.leaveCategory),
        const _LegendItem(
          label: "Holiday",
          color: CalendarTypeStyle.holidayCategory,
        ),
        const _LegendItem(label: "Week Off", color: Color(0xFF8B5CF6)),
        for (final item in typeLegend)
          _LegendItem(label: item.label, color: item.color),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
