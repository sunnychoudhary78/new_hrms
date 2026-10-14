import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

enum AttendanceRange { week, month, year }

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
  static const double barWidth = 14;
  static const int visibleDays = 5;

  AttendanceRange _range = AttendanceRange.week;
  late int startIndex;
  late List<WeeklyAttendanceBar> visibleList;
  late double maxY;

  static int initialStartIndexForToday(List<WeeklyAttendanceBar> days) {
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var endIndex = -1;
    for (var i = 0; i < days.length; i++) {
      final d = days[i].date;
      final dayOnly = DateTime(d.year, d.month, d.day);
      if (!dayOnly.isAfter(today)) {
        endIndex = i;
      }
    }

    if (endIndex < 0) return 0;

    final maxStart = (days.length - visibleDays).clamp(0, days.length);
    return (endIndex - (visibleDays - 1)).clamp(0, maxStart);
  }

  @override
  void initState() {
    super.initState();
    startIndex = initialStartIndexForToday(widget.days);
    _updateVisibleList();
  }

  @override
  void didUpdateWidget(covariant LastFiveDaysAttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      startIndex = initialStartIndexForToday(widget.days);
      _updateVisibleList();
    }
  }

  /// Past (and today) days only — future days are never charted.
  List<WeeklyAttendanceBar> get _eligibleDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.days.where((d) {
      final day = DateTime(d.date.year, d.date.month, d.date.day);
      return !day.isAfter(today);
    }).toList();
  }

  void _updateVisibleList() {
    final source = _eligibleDays;
    if (source.isEmpty) {
      visibleList = const [];
      maxY = 8;
      return;
    }

    // Week / Month / Year all use a 5-day window so X labels never overlap.
    final maxStart = (source.length - visibleDays).clamp(0, source.length);
    startIndex = startIndex.clamp(0, maxStart);
    visibleList = source.sublist(
      startIndex,
      (startIndex + visibleDays).clamp(0, source.length),
    );

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

  void _goPrevious() {
    final source = _eligibleDays;
    if (startIndex == 0) {
      widget.onPreviousMonth?.call();
      return;
    }
    setState(() {
      startIndex = (startIndex - visibleDays).clamp(0, source.length);
      _updateVisibleList();
    });
  }

  void _goNext() {
    final source = _eligibleDays;
    if (startIndex + visibleDays >= source.length) {
      widget.onNextMonth?.call();
      return;
    }
    setState(() {
      startIndex = (startIndex + visibleDays).clamp(0, source.length);
      _updateVisibleList();
    });
  }

  bool get _canGoPreviousWindow {
    if (startIndex > 0) return true;
    return widget.canGoToPreviousMonth;
  }

  bool get _canGoNextWindow {
    if (startIndex + visibleDays < _eligibleDays.length) return true;
    return widget.canGoToNextMonth;
  }

  /// Average over days that actually count (expected or worked > 0), so
  /// week-offs / empty future slots don't pull the average to 0.0.
  double get _avgWorkedHours {
    final counted = visibleList
        .where((d) => d.expectedMinutes > 0 || d.workedMinutes > 0)
        .toList();
    if (counted.isEmpty) return 0;
    final total = counted.fold<int>(0, (s, e) => s + e.workedMinutes);
    return double.parse((total / counted.length / 60).toStringAsFixed(1));
  }

  double get _totalWorkedHours {
    final total = visibleList.fold<int>(0, (s, e) => s + e.workedMinutes);
    return double.parse((total / 60).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final dash = HomeDashColors.of(context);
    final periodLabel = _range == AttendanceRange.year
        ? DateFormat('yyyy').format(widget.month)
        : DateFormat('MMMM yyyy').format(widget.month);

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
                      periodLabel,
                      style: TextStyle(
                        fontSize: 12,
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
                    startIndex = initialStartIndexForToday(_eligibleDays);
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
                icon: Icon(Icons.chevron_right_rounded),
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
            child: visibleList.isEmpty
                ? Center(
                    child: Text(
                      'No attendance data',
                      style: TextStyle(color: HomeDashColors.muted),
                    ),
                  )
                : BarChart(_chartData()),
          ),
          SizedBox(height: 14),
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
                    SizedBox(height: 2),
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
              // Only draw the label for the exact integer slot.
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
              width: barWidth,
              borderRadius: BorderRadius.circular(5),
              color: HomeDashColors.expected,
            ),
            if (worked > 0)
              BarChartRodData(
                toY: worked,
                width: barWidth,
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
          chip(AttendanceRange.year, 'Year'),
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
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: HomeDashColors.muted),
        ),
      ],
    );
  }
}
