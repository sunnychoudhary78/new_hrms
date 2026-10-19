import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

enum AttendanceRange { week, month }

class LastFiveDaysAttendanceCard extends StatefulWidget {
  final List<WeeklyAttendanceBar> days;
  final bool canGoToPreviousMonth;
  final bool canGoToNextMonth;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final DateTime month;

  const LastFiveDaysAttendanceCard({
    super.key,
    required this.days,
    required this.month,
    this.canGoToPreviousMonth = false,
    this.canGoToNextMonth = false,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  @override
  State<LastFiveDaysAttendanceCard> createState() =>
      _LastFiveDaysAttendanceCardState();
}

class _LastFiveDaysAttendanceCardState
    extends State<LastFiveDaysAttendanceCard> {
  static const double chartHeight = 200;
  static const int monthPageSize = 7;

  AttendanceRange _range = AttendanceRange.week;

  /// Sunday of the currently displayed calendar week (week mode).
  late DateTime _weekStart;

  /// Start index into month calendar days (month mode paging).
  late int _monthStartIndex;

  late List<WeeklyAttendanceBar> visibleList;
  late double maxY;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Sunday on or before [day] (calendar week starts Sunday).
  static DateTime sundayOf(DateTime day) {
    final d = _dateOnly(day);
    // DateTime.weekday: Mon=1 … Sun=7
    final daysFromSunday = d.weekday % 7;
    return d.subtract(Duration(days: daysFromSunday));
  }

  static DateTime saturdayOf(DateTime weekStart) =>
      _dateOnly(weekStart).add(const Duration(days: 6));

  Map<String, WeeklyAttendanceBar> get _barsByDate {
    final map = <String, WeeklyAttendanceBar>{};
    for (final bar in widget.days) {
      final d = _dateOnly(bar.date);
      map[_key(d)] = WeeklyAttendanceBar(
        date: d,
        workedMinutes: bar.workedMinutes,
        expectedMinutes: bar.expectedMinutes,
        estimatedOtMinutes: bar.estimatedOtMinutes,
        isCapped: bar.isCapped,
      );
    }
    return map;
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Full calendar days for the loaded month (1 … last day).
  List<DateTime> get _monthDates {
    final first = DateTime(widget.month.year, widget.month.month, 1);
    final last = DateTime(widget.month.year, widget.month.month + 1, 0);
    final out = <DateTime>[];
    var cursor = first;
    while (!cursor.isAfter(last)) {
      out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  WeeklyAttendanceBar _barFor(DateTime day) {
    final d = _dateOnly(day);
    final existing = _barsByDate[_key(d)];
    if (existing != null) return existing;
    return WeeklyAttendanceBar(date: d, workedMinutes: 0, expectedMinutes: 0);
  }

  /// Past + today only for averages; future days still listed in week view
  /// with zero values so the Sun–Sat axis stays complete.
  List<WeeklyAttendanceBar> _weekBars(DateTime weekStart) {
    final start = _dateOnly(weekStart);
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      final bar = _barFor(day);
      if (day.isAfter(_today)) {
        return WeeklyAttendanceBar(
          date: day,
          workedMinutes: 0,
          expectedMinutes: 0,
        );
      }
      return bar;
    });
  }

  DateTime get _latestWeekStart {
    final last = DateTime(widget.month.year, widget.month.month + 1, 0);
    final anchor = last.isAfter(_today) ? _today : last;
    // Prefer a week that still intersects this month.
    var start = sundayOf(anchor);
    final monthStart = DateTime(widget.month.year, widget.month.month, 1);
    if (saturdayOf(start).isBefore(monthStart)) {
      start = sundayOf(monthStart);
    }
    return start;
  }

  void _initRangePosition() {
    final today = _today;
    final monthStart = DateTime(widget.month.year, widget.month.month, 1);
    final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);

    if (_range == AttendanceRange.week) {
      DateTime start;
      if (!today.isBefore(monthStart) && !today.isAfter(monthEnd)) {
        start = sundayOf(today);
      } else if (today.isBefore(monthStart)) {
        start = sundayOf(monthStart);
      } else {
        start = _latestWeekStart;
      }
      // Keep week intersecting the loaded month.
      if (saturdayOf(start).isBefore(monthStart)) {
        start = sundayOf(monthStart);
      }
      if (start.isAfter(monthEnd)) {
        start = sundayOf(monthEnd);
      }
      _weekStart = start;
    } else {
      final dates = _monthDates;
      if (dates.isEmpty) {
        _monthStartIndex = 0;
        return;
      }
      var endIndex = -1;
      for (var i = 0; i < dates.length; i++) {
        if (!dates[i].isAfter(today)) endIndex = i;
      }
      if (endIndex < 0) endIndex = 0;
      final maxStart = (dates.length - monthPageSize).clamp(0, dates.length);
      _monthStartIndex = (endIndex - (monthPageSize - 1)).clamp(0, maxStart);
    }
  }

  void _updateVisibleList() {
    if (_range == AttendanceRange.week) {
      visibleList = _weekBars(_weekStart);
    } else {
      final dates = _monthDates;
      if (dates.isEmpty) {
        visibleList = const [];
        maxY = 8;
        return;
      }
      final maxStart = (dates.length - monthPageSize).clamp(0, dates.length);
      _monthStartIndex = _monthStartIndex.clamp(0, maxStart);
      final end = (_monthStartIndex + monthPageSize).clamp(0, dates.length);
      visibleList = dates.sublist(_monthStartIndex, end).map((d) {
        if (d.isAfter(_today)) {
          return WeeklyAttendanceBar(
            date: d,
            workedMinutes: 0,
            expectedMinutes: 0,
          );
        }
        return _barFor(d);
      }).toList();
    }
    maxY = _calculateMaxY();
  }

  double _calculateMaxY() {
    if (visibleList.isEmpty) return 8;

    final maxMinutes = visibleList
        .map(
          (e) => e.workedMinutes > e.expectedMinutes
              ? e.workedMinutes
              : e.expectedMinutes,
        )
        .reduce((a, b) => a > b ? a : b);

    const interval = 2.0;
    final rawHours = (maxMinutes / 60) * 1.2;
    final snapped = (rawHours / interval).ceilToDouble() * interval;
    return snapped < 8 ? 8 : snapped;
  }

  bool get _weekIntersectsMonth {
    final monthStart = DateTime(widget.month.year, widget.month.month, 1);
    final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);
    final weekEnd = saturdayOf(_weekStart);
    return !weekEnd.isBefore(monthStart) && !_weekStart.isAfter(monthEnd);
  }

  void _goPrevious() {
    if (_range == AttendanceRange.week) {
      final prev = _weekStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(widget.month.year, widget.month.month, 1);
      if (saturdayOf(prev).isBefore(monthStart)) {
        widget.onPreviousMonth?.call();
        return;
      }
      setState(() {
        _weekStart = prev;
        _updateVisibleList();
      });
      return;
    }

    if (_monthStartIndex == 0) {
      widget.onPreviousMonth?.call();
      return;
    }
    setState(() {
      _monthStartIndex =
          (_monthStartIndex - monthPageSize).clamp(0, _monthDates.length);
      _updateVisibleList();
    });
  }

  void _goNext() {
    if (_range == AttendanceRange.week) {
      final next = _weekStart.add(const Duration(days: 7));
      final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);
      if (next.isAfter(monthEnd)) {
        widget.onNextMonth?.call();
        return;
      }
      // Don't advance into a fully future week with no past/today days.
      if (next.isAfter(_today)) {
        return;
      }
      setState(() {
        _weekStart = next;
        _updateVisibleList();
      });
      return;
    }

    final dates = _monthDates;
    if (_monthStartIndex + monthPageSize >= dates.length) {
      widget.onNextMonth?.call();
      return;
    }
    setState(() {
      _monthStartIndex =
          (_monthStartIndex + monthPageSize).clamp(0, dates.length);
      _updateVisibleList();
    });
  }

  bool get _canGoPreviousWindow {
    if (_range == AttendanceRange.week) {
      final prev = _weekStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(widget.month.year, widget.month.month, 1);
      if (!saturdayOf(prev).isBefore(monthStart)) return true;
      return widget.canGoToPreviousMonth;
    }
    if (_monthStartIndex > 0) return true;
    return widget.canGoToPreviousMonth;
  }

  bool get _canGoNextWindow {
    if (_range == AttendanceRange.week) {
      final next = _weekStart.add(const Duration(days: 7));
      final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);
      if (!next.isAfter(monthEnd) && !next.isAfter(_today)) return true;
      if (next.isAfter(monthEnd)) return widget.canGoToNextMonth;
      return false;
    }
    if (_monthStartIndex + monthPageSize < _monthDates.length) {
      // Only if the next page has a non-future day.
      final nextStart = _monthStartIndex + monthPageSize;
      if (nextStart < _monthDates.length &&
          !_monthDates[nextStart].isAfter(_today)) {
        return true;
      }
    }
    return widget.canGoToNextMonth;
  }

  /// Average over days that actually count (expected or worked > 0), so
  /// week-offs / empty future slots don't pull the average to 0.0.
  double get _avgWorkedHours {
    final counted = visibleList
        .where(
          (d) =>
              !d.date.isAfter(_today) &&
              (d.expectedMinutes > 0 || d.workedMinutes > 0),
        )
        .toList();
    if (counted.isEmpty) return 0;
    final total = counted.fold<int>(0, (s, e) => s + e.workedMinutes);
    return double.parse((total / counted.length / 60).toStringAsFixed(1));
  }

  double get _totalWorkedHours {
    final total = visibleList
        .where((d) => !d.date.isAfter(_today))
        .fold<int>(0, (s, e) => s + e.workedMinutes);
    return double.parse((total / 60).toStringAsFixed(1));
  }

  String get _periodLabel {
    if (_range == AttendanceRange.week) {
      final start = _dateOnly(_weekStart);
      final end = saturdayOf(start);
      final sameYear = start.year == end.year;
      final sameMonth = sameYear && start.month == end.month;
      if (sameMonth) {
        return '${DateFormat('EEEE, MMMM d').format(start)}'
            ' – ${DateFormat('EEEE, MMMM d, yyyy').format(end)}';
      }
      if (sameYear) {
        return '${DateFormat('EEEE, MMMM d').format(start)}'
            ' – ${DateFormat('EEEE, MMMM d, yyyy').format(end)}';
      }
      return '${DateFormat('EEEE, MMMM d, yyyy').format(start)}'
          ' – ${DateFormat('EEEE, MMMM d, yyyy').format(end)}';
    }
    return DateFormat('MMMM yyyy').format(widget.month);
  }

  double get _barWidth {
    if (_range == AttendanceRange.week) return 12;
    return visibleList.length > 10 ? 8 : 12;
  }

  @override
  void initState() {
    super.initState();
    _monthStartIndex = 0;
    _weekStart = sundayOf(_today);
    _initRangePosition();
    _updateVisibleList();
  }

  @override
  void didUpdateWidget(covariant LastFiveDaysAttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days ||
        oldWidget.month != widget.month) {
      _initRangePosition();
      _updateVisibleList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final dash = HomeDashColors.of(context);

    return HomeDashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: dash.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _periodLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: dash.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (v) {
                  setState(() {
                    _range = v;
                    _initRangePosition();
                    _updateVisibleList();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _canGoPreviousWindow ? _goPrevious : null,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  splashFactory:
                      isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _canGoNextWindow ? _goNext : null,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  splashFactory:
                      isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
                ),
              ),
            ],
          ),
          SizedBox(
            height: chartHeight,
            child: visibleList.isEmpty ||
                    (_range == AttendanceRange.week && !_weekIntersectsMonth)
                ? Center(
                    child: Text(
                      'No attendance data',
                      style: TextStyle(color: HomeDashColors.muted),
                    ),
                  )
                : BarChart(_chartData()),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_avgWorkedHours.toStringAsFixed(1)} hrs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HomeDashColors.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Avg · ${_totalWorkedHours.toStringAsFixed(1)} hrs total',
                      style: TextStyle(
                        fontSize: 11,
                        color: HomeDashColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _Legend(HomeDashColors.worked, 'Worked'),
                    _Legend(HomeDashColors.expected, 'Expected'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BarChartData _chartData() {
    return BarChartData(
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        horizontalInterval: 2,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: const Color(0xFFE2E8F0),
          strokeWidth: 1,
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex < 0 || groupIndex >= visibleList.length) {
              return null;
            }
            final d = visibleList[groupIndex];
            final label = DateFormat('EEEE, MMMM d, yyyy').format(d.date);
            final worked = (d.workedMinutes / 60).toStringAsFixed(1);
            final expected = (d.expectedMinutes / 60).toStringAsFixed(1);
            return BarTooltipItem(
              '$label\nWorked ${worked}h · Expected ${expected}h',
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HomeDashColors.title,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: 2,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}h',
                style: TextStyle(
                  fontSize: 10,
                  color: HomeDashColors.muted,
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= visibleList.length) {
                return const SizedBox.shrink();
              }
              if (value != index.toDouble()) {
                return const SizedBox.shrink();
              }
              final date = visibleList[index].date;
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: HomeDashColors.muted,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: HomeDashColors.title,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(visibleList.length, (index) {
        final d = visibleList[index];
        final worked = d.workedMinutes / 60.0;
        final expected = d.expectedMinutes / 60.0;

        return BarChartGroupData(
          x: index,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: expected > 0 ? expected : 0,
              width: _barWidth,
              borderRadius: BorderRadius.circular(5),
              color: HomeDashColors.expected,
            ),
            if (worked > 0)
              BarChartRodData(
                toY: worked,
                width: _barWidth,
                borderRadius: BorderRadius.circular(5),
                color: HomeDashColors.worked,
              ),
          ],
        );
      }),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final AttendanceRange value;
  final ValueChanged<AttendanceRange> onChanged;

  const _RangeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dash = HomeDashColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget chip(AttendanceRange range, String label) {
      final selected = value == range;
      return GestureDetector(
        onTap: () => onChanged(range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? dash.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : dash.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(AttendanceRange.week, 'Week'),
          chip(AttendanceRange.month, 'Month'),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend(this.color, this.label);

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
          style: TextStyle(fontSize: 10, color: HomeDashColors.muted),
        ),
      ],
    );
  }
}
