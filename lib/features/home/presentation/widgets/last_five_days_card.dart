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

  void _updateVisibleList() {
    if (widget.days.isEmpty) {
      visibleList = const [];
      maxY = 8;
      return;
    }

    switch (_range) {
      case AttendanceRange.week:
        visibleList = widget.days.sublist(
          startIndex,
          (startIndex + visibleDays).clamp(0, widget.days.length),
        );
      case AttendanceRange.month:
      case AttendanceRange.year:
        // Month/year share month bars; year keeps current month snapshot.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        visibleList = widget.days
            .where((d) {
              final day = DateTime(d.date.year, d.date.month, d.date.day);
              return !day.isAfter(today);
            })
            .toList();
        if (visibleList.length > 10) {
          visibleList = visibleList.sublist(visibleList.length - 10);
        }
        if (visibleList.isEmpty) {
          visibleList = widget.days.length > visibleDays
              ? widget.days.sublist(widget.days.length - visibleDays)
              : widget.days;
        }
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

  void _goPrevious() {
    if (_range != AttendanceRange.week) {
      widget.onPreviousMonth?.call();
      return;
    }
    if (startIndex == 0) {
      widget.onPreviousMonth?.call();
      return;
    }
    setState(() {
      startIndex = (startIndex - visibleDays).clamp(0, widget.days.length);
      _updateVisibleList();
    });
  }

  void _goNext() {
    if (_range != AttendanceRange.week) {
      widget.onNextMonth?.call();
      return;
    }
    if (startIndex + visibleDays >= widget.days.length) {
      widget.onNextMonth?.call();
      return;
    }
    setState(() {
      startIndex = (startIndex + visibleDays).clamp(0, widget.days.length);
      _updateVisibleList();
    });
  }

  double get _avgWorkedHours {
    if (visibleList.isEmpty) return 0;
    final total = visibleList.fold<int>(0, (s, e) => s + e.workedMinutes);
    return double.parse((total / visibleList.length / 60).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
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
                    const Text(
                      'Attendance Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeDashColors.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HomeDashColors.muted,
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
                    if (v == AttendanceRange.week) {
                      startIndex = initialStartIndexForToday(widget.days);
                    }
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
                onPressed: (_range == AttendanceRange.week
                        ? startIndex == 0 && !widget.canGoToPreviousMonth
                        : !widget.canGoToPreviousMonth)
                    ? null
                    : _goPrevious,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  splashFactory:
                      isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: (_range == AttendanceRange.week
                        ? startIndex + visibleDays >= widget.days.length &&
                            !widget.canGoToNextMonth
                        : !widget.canGoToNextMonth)
                    ? null
                    : _goNext,
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
                ? const Center(
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HomeDashColors.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Avg work hours',
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
                  spacing: 10,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: const [
                    _Legend(HomeDashColors.worked, 'Worked'),
                    _Legend(HomeDashColors.overtime, 'Overtime'),
                    _Legend(HomeDashColors.capped, 'Auto-close'),
                    _Legend(HomeDashColors.expected, 'Expected'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: HomeDashColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Estimated OT — final amount appears on payslip after payroll.',
                  style: TextStyle(
                    fontSize: 11,
                    color: HomeDashColors.muted.withValues(alpha: 0.95),
                  ),
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
                style: const TextStyle(
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
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= visibleList.length) {
                return const SizedBox();
              }
              final date = visibleList[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  DateFormat('E d').format(date),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: HomeDashColors.muted,
                  ),
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
        final overtime = worked > expected ? worked - expected : 0.0;
        final normal = worked - overtime;
        final tipColor =
            d.isCapped ? HomeDashColors.capped : HomeDashColors.overtime;

        return BarChartGroupData(
          x: index,
          barsSpace: 3,
          barRods: [
            BarChartRodData(
              toY: expected,
              width: barWidth,
              borderRadius: BorderRadius.circular(5),
              color: HomeDashColors.expected,
            ),
            BarChartRodData(
              toY: worked <= 0 ? 0.05 : worked,
              width: barWidth,
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF6366F1), Color(0xFF93C5FD)],
              ),
              rodStackItems: [
                if (normal > 0)
                  BarChartRodStackItem(0, normal, HomeDashColors.worked),
                if (overtime > 0)
                  BarChartRodStackItem(normal, worked, tipColor),
              ],
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
    Widget chip(AttendanceRange range, String label) {
      final selected = value == range;
      return GestureDetector(
        onTap: () => onChanged(range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? HomeDashColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : HomeDashColors.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
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
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: HomeDashColors.muted),
        ),
      ],
    );
  }
}
