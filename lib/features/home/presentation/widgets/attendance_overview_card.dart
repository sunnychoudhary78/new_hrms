import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';

class AttendanceColors {
  static const worked = Color(0xFF16A34A);
  static const overtime = Color(0xFF22C55E);
  static const leave = Color(0xFFF59E0B);
  static const absent = Color(0xFFDC2626);
  static const late = Color(0xFF7C3AED);
  static const expected = Color(0xFF94A3B8);
}

class AttendanceOverviewCard extends StatelessWidget {
  final HomeDashboardModel dashboard;

  const AttendanceOverviewCard({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Monthly Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _AttendancePieChart(
                      distribution: dashboard.distribution,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    flex: 2,
                    child: _PieLegend(distribution: dashboard.distribution),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 12),
            _WorkedVsExpectedBar(attendance: dashboard.attendance),
          ],
        ),
      ),
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
        value: distribution.worked,
        color: AttendanceColors.worked,
        total: total,
      ),
      _section(
        value: distribution.leave,
        color: AttendanceColors.leave,
        total: total,
      ),
      _section(
        value: distribution.absent,
        color: AttendanceColors.absent,
        total: total,
      ),
      _section(
        value: distribution.late,
        color: AttendanceColors.late,
        total: total,
      ),
    ].whereType<PieChartSectionData>().toList();

    if (sections.isEmpty) {
      return const Center(
        child: Text(
          "No attendance data",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
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

    final percent = ((value / total) * 100).toStringAsFixed(0);
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 45,
      showTitle: true,
      title: "$percent%",
      titleStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
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
          color: AttendanceColors.worked,
          label: 'Worked',
          value: distribution.worked,
        ),
        const SizedBox(height: 10),
        _LegendItem(
          color: AttendanceColors.leave,
          label: 'Leave',
          value: distribution.leave,
        ),
        const SizedBox(height: 10),
        _LegendItem(
          color: AttendanceColors.absent,
          label: 'Absent',
          value: distribution.absent,
        ),
        const SizedBox(height: 10),
        _LegendItem(
          color: AttendanceColors.late,
          label: 'Late',
          value: distribution.late,
        ),
        const SizedBox(height: 12),
        Text(
          "Tracked: ${distribution.total.toStringAsFixed(0)} days",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$label (${value.toStringAsFixed(0)})",
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _WorkedVsExpectedBar extends StatelessWidget {
  final AttendanceOverview attendance;

  const _WorkedVsExpectedBar({required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModernProgressBar(
          label: 'Worked',
          value: attendance.workedHours,
          max: attendance.expectedHours,
          color: AttendanceColors.worked,
        ),
        const SizedBox(height: 14),
        _ModernProgressBar(
          label: 'Expected',
          value: attendance.expectedHours,
          max: attendance.expectedHours,
          color: AttendanceColors.expected,
        ),
      ],
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
    final scheme = Theme.of(context).colorScheme;
    final double percent = max == 0 ? 0.0 : (value / max).clamp(0, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toStringAsFixed(1)} hrs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.85), color],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
