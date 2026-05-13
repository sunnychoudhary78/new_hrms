import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AttendancePieChart extends StatelessWidget {
  final int present;
  final int absent;
  final int late;
  final int leave;

  const AttendancePieChart({
    super.key,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
  });

  int get total => present + absent + late + leave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 60,
                  sectionsSpace: 4,
                  sections: [
                    _section("Present", present, scheme.primary),
                    _section("Late", late, scheme.tertiary),
                    _section("Leave", leave, scheme.secondary),
                    _section("Absent", absent, scheme.error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _legend("Present", present, scheme.primary),
                _legend("Late", late, scheme.tertiary),
                _legend("Leave", leave, scheme.secondary),
                _legend("Absent", absent, scheme.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(String t, int v, Color c) {
    if (v == 0) return PieChartSectionData(value: 0);

    return PieChartSectionData(
      value: v.toDouble(),
      color: c,
      radius: 30,
      title: "${((v / total) * 100).toStringAsFixed(0)}%",
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _legend(String t, int v, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text("$t ($v)"),
      ],
    );
  }
}
