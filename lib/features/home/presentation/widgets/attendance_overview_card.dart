import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class AttendanceOverviewCard extends StatelessWidget {
  final HomeDashboardModel dashboard;

  const AttendanceOverviewCard({super.key, required this.dashboard});

  String _trackedDaysLabel(AttendanceDistribution d) {
    final total = d.total;
    if (total <= 0) return '0';
    if (total == total.roundToDouble()) return total.toStringAsFixed(0);
    return total.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      dashboard.attendanceMonth.year,
      dashboard.attendanceMonth.month + 1,
      0,
    ).day;

    return Column(
      children: [
        HomeDashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attendance Monthly Overview',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HomeDashColors.title,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM yyyy').format(dashboard.attendanceMonth),
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeDashColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _AttendancePieChart(
                            distribution: dashboard.distribution,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _trackedDaysLabel(dashboard.distribution),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: HomeDashColors.title,
                                ),
                              ),
                              Text(
                                'of $daysInMonth days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: HomeDashColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _PieLegend(distribution: dashboard.distribution),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        HomeDashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Keep going!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: HomeDashColors.title,
                      ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: HomeDashColors.softBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      color: HomeDashColors.accentBlue,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Track your progress against expected hours.',
                style: TextStyle(
                  fontSize: 12,
                  color: HomeDashColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              _ModernProgressBar(
                label: 'Worked',
                value: dashboard.attendance.workedHours,
                max: dashboard.attendance.expectedHours > 0
                    ? dashboard.attendance.expectedHours
                    : 1,
                color: HomeDashColors.accentGreen,
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expected (target)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HomeDashColors.title,
                      ),
                    ),
                  ),
                  Text(
                    '${dashboard.attendance.expectedHours.toStringAsFixed(1)} hrs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HomeDashColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendancePieChart extends StatelessWidget {
  final AttendanceDistribution distribution;

  const _AttendancePieChart({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.total;
    final sections = <PieChartSectionData?>[
      _section(
        value: distribution.leave,
        color: HomeDashColors.leave,
        total: total,
      ),
      _section(
        value: distribution.absent,
        color: HomeDashColors.absent,
        total: total,
      ),
      _section(
        value: distribution.weekOff,
        color: HomeDashColors.weekOff,
        total: total,
      ),
      _section(
        value: distribution.holiday,
        color: HomeDashColors.accentBlue,
        total: total,
      ),
      _section(
        value: distribution.worked,
        color: const Color(0xFF34D399),
        total: total,
      ),
    ].whereType<PieChartSectionData>().toList();

    if (sections.isEmpty) {
      return const Center(
        child: Text(
          'No attendance data',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        startDegreeOffset: -90,
        sections: sections,
      ),
    );
  }

  PieChartSectionData? _section({
    required double value,
    required Color color,
    required double total,
  }) {
    if (value <= 0 || total <= 0) return null;

    return PieChartSectionData(
      value: value,
      color: color,
      radius: 28,
      showTitle: false,
    );
  }
}

class _PieLegend extends StatelessWidget {
  final AttendanceDistribution distribution;

  const _PieLegend({required this.distribution});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendItem(
          color: const Color(0xFF34D399),
          label: 'Working',
          value: distribution.worked,
          percent: distribution.percent(distribution.worked),
        ),
        _LegendItem(
          color: HomeDashColors.leave,
          label: 'Leave',
          value: distribution.leave,
          percent: distribution.percent(distribution.leave),
        ),
        _LegendItem(
          color: HomeDashColors.absent,
          label: 'Absent',
          value: distribution.absent,
          percent: distribution.percent(distribution.absent),
        ),
        _LegendItem(
          color: HomeDashColors.weekOff,
          label: 'Week Off',
          value: distribution.weekOff,
          percent: distribution.percent(distribution.weekOff),
        ),
        _LegendItem(
          color: HomeDashColors.accentBlue,
          label: 'Holiday',
          value: distribution.holiday,
          percent: distribution.percent(distribution.holiday),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double value;
  final double percent;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: HomeDashColors.title,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HomeDashColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _ModernProgressBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HomeDashColors.title,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)} hrs',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}
