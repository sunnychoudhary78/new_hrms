import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/core/theme/app_design.dart';
import '../../data/models/leave_balance_model.dart';
import '../utils/leave_color_mapper.dart';

class LeavePieChart extends StatelessWidget {
  final List<LeaveBalance> leaves;

  const LeavePieChart({super.key, required this.leaves});

  @override
  Widget build(BuildContext context) {
    final chartLeaves = leaves
        .where((leave) => !leave.name.toLowerCase().contains('emergency'))
        .toList();

    final sanitizedLeaves = chartLeaves
        .map((l) => l.available < 0 ? 0.0 : l.available)
        .toList();

    final totalAvailable = sanitizedLeaves.fold<double>(0, (s, v) => s + v);

    if (totalAvailable <= 0) {
      return Container(
        height: 280,
        decoration: AppColors.cardDecoration(),
        alignment: Alignment.center,
        child: const Text(
          "No leave balance available",
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return Container(
      decoration: AppColors.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: SizedBox(
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 90,
                startDegreeOffset: -90,
                sections: List.generate(chartLeaves.length, (index) {
                  final leave = chartLeaves[index];
                  final value = leave.available < 0 ? 0.0 : leave.available;

                  final percent = (value / totalAvailable) * 100;

                  return PieChartSectionData(
                    value: value,
                    color: LeaveColorMapper.colorFor(leave.name),
                    radius: 40,
                    title: value == 0 ? "" : '${percent.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Available",
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  totalAvailable.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Days",
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
