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
  final ScrollController _scrollController = ScrollController();

  static const double chartHeight = 220;

  static const double barWidth = 12;
  static const double groupSpace = 28;
  static const double groupWidth = (barWidth * 2) + groupSpace;

  static const int visibleDays = 5;

  late double maxY;

  @override
  void initState() {
    super.initState();

    maxY = _calculateMaxY();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLastFiveDays();
    });
  }

  double _calculateMaxY() {
    if (widget.days.isEmpty) return 8;

    final maxMinutes = widget.days
        .map(
          (e) => e.workedMinutes > e.expectedMinutes
              ? e.workedMinutes
              : e.expectedMinutes,
        )
        .reduce((a, b) => a > b ? a : b);

    return ((maxMinutes / 60) * 1.2).ceilToDouble();
  }

  void _scrollToLastFiveDays() {
    if (!_scrollController.hasClients) return;

    final total = widget.days.length;

    if (total <= visibleDays) return;

    final offset = (total - visibleDays) * groupWidth;

    _scrollController.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) {
      return const SizedBox();
    }

    final chartWidth = widget.days.length * groupWidth + 40;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attendance Overview",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: chartHeight,
            child: Row(
              children: [
                /// FIXED Y AXIS
                SizedBox(
                  width: 44,
                  child: BarChart(_chartData(showYAxis: true, showBars: false)),
                ),

                /// SCROLLABLE BARS
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: BarChart(
                        _chartData(showYAxis: false, showBars: true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

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

      gridData: FlGridData(
        show: showYAxis,
        horizontalInterval: 2,
        drawVerticalLine: false,
      ),

      borderData: FlBorderData(show: false),

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

              if (index < 0 || index >= widget.days.length) {
                return const SizedBox();
              }

              final date = widget.days[index].date;

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

      barGroups: showBars
          ? List.generate(widget.days.length, (index) {
              final d = widget.days[index];

              final worked = d.workedMinutes / 60;
              final expected = d.expectedMinutes / 60;

              final overtime = worked > expected ? worked - expected : 0;

              final normal = worked - overtime;

              return BarChartGroupData(
                x: index,
                barsSpace: 4,
                barRods: [
                  /// Expected bar
                  BarChartRodData(
                    toY: expected,
                    width: barWidth,
                    color: AttendanceColors.expected,
                    borderRadius: BorderRadius.circular(3),
                  ),

                  /// Worked stacked bar
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
          : [],
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
