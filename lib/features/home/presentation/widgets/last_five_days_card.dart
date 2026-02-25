import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';

class AttendanceColors {
  static const worked = Color(0xFF16A34A);
  static const overtime = Color(0xFF22C55E);
  static const capped = Color(0xFFF59E0B);
  static const expected = Color(0xFF94A3B8);
}

class LastFiveDaysAttendanceCard extends StatefulWidget {
  final List<WeeklyAttendanceBar> days;

  const LastFiveDaysAttendanceCard({super.key, required this.days});

  @override
  State<LastFiveDaysAttendanceCard> createState() =>
      _LastFiveDaysAttendanceCardState();
}

class _LastFiveDaysAttendanceCardState
    extends State<LastFiveDaysAttendanceCard> {
  static const double chartHeight = 220;
  static const double barWidth = 12;
  static const double groupSpace = 28;
  static const double groupWidth = (barWidth * 2) + groupSpace;

  static const int visibleDays = 5;

  late int startIndex;
  late List<WeeklyAttendanceBar> visibleList;
  late double maxY;

  @override
  void initState() {
    super.initState();

    startIndex = (widget.days.length - visibleDays).clamp(
      0,
      widget.days.length,
    );

    _updateVisibleList();
  }

  void _updateVisibleList() {
    visibleList = widget.days.sublist(
      startIndex,
      (startIndex + visibleDays).clamp(0, widget.days.length),
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

    return ((maxMinutes / 60) * 1.2).ceilToDouble();
  }

  void _goPrevious() {
    if (startIndex == 0) return;

    setState(() {
      startIndex = (startIndex - visibleDays).clamp(0, widget.days.length);
      _updateVisibleList();
    });
  }

  void _goNext() {
    if (startIndex + visibleDays >= widget.days.length) return;

    setState(() {
      startIndex = (startIndex + visibleDays).clamp(0, widget.days.length);
      _updateVisibleList();
    });
  }

  String get currentMonthText {
    if (visibleList.isEmpty) return "";
    return DateFormat('MMMM yyyy').format(visibleList.last.date);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox();

    final chartWidth = visibleList.length * groupWidth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Attendance Overview",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentMonthText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: startIndex == 0 ? null : _goPrevious,
                        visualDensity: VisualDensity.compact,
                      ),

                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            startIndex + visibleDays >= widget.days.length
                            ? null
                            : _goNext,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// CHART
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// Y AXIS ONLY (NO BARS)
                SizedBox(
                  width: 44,
                  child: BarChart(
                    _chartData(
                      showYAxis: true,
                      showBars: false, // IMPORTANT FIX
                    ),
                  ),
                ),

                /// MAIN CHART WITH BARS
                SizedBox(
                  width: chartWidth,
                  child: BarChart(
                    _chartData(
                      showYAxis: false,
                      showBars: true, // IMPORTANT FIX
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// LEGEND
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(AttendanceColors.worked, "Worked"),
              SizedBox(width: 16),
              _Legend(AttendanceColors.overtime, "Overtime"),
              SizedBox(width: 16),
              _Legend(AttendanceColors.capped, "Capped"),
              SizedBox(width: 16),
              _Legend(AttendanceColors.expected, "Expected"),
            ],
          ),
        ],
      ),
    );
  }

  BarChartData _chartData({required bool showYAxis, required bool showBars}) {
    return BarChartData(
      maxY: maxY,

      alignment: BarChartAlignment.start,

      groupsSpace: groupSpace,

      borderData: FlBorderData(show: false),

      gridData: FlGridData(
        show: showYAxis,
        horizontalInterval: 2,
        drawVerticalLine: false,
      ),

      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: showYAxis,
            reservedSize: 40,
            interval: 2,
            getTitlesWidget: (value, meta) {
              return Text(
                "${value.toInt()}h",
                style: const TextStyle(fontSize: 11),
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
            showTitles: showBars,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();

              if (index < 0 || index >= visibleList.length) {
                return const SizedBox();
              }

              final date = visibleList[index].date;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d').format(date),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    DateFormat('E').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
      ),

      /// CRITICAL FIX — NO BARS FOR Y AXIS CHART
      barGroups: showBars
          ? List.generate(visibleList.length, (index) {
              final d = visibleList[index];

              final worked = d.workedMinutes / 60;
              final expected = d.expectedMinutes / 60;

              final overtime = worked > expected ? worked - expected : 0;

              final normal = worked - overtime;

              return BarChartGroupData(
                x: index,
                barsSpace: 4,
                barRods: [
                  /// EXPECTED
                  BarChartRodData(
                    toY: expected,
                    width: barWidth,
                    color: AttendanceColors.expected,
                    borderRadius: BorderRadius.circular(3),
                  ),

                  /// WORKED STACK
                  BarChartRodData(
                    toY: worked,
                    width: barWidth,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      if (normal > 0)
                        BarChartRodStackItem(
                          0,
                          normal,
                          AttendanceColors.worked,
                        ),

                      if (overtime > 0)
                        BarChartRodStackItem(
                          normal,
                          worked,
                          d.isCapped
                              ? AttendanceColors.capped
                              : AttendanceColors.overtime,
                        ),
                    ],
                  ),
                ],
              );
            })
          : [], // ← THIS REMOVES GHOST BAR
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
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
