import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/leave_balance_model.dart';
import '../utils/leave_color_mapper.dart';

class LeavePieChart extends StatelessWidget {
  final List<LeaveBalance> leaves;

  const LeavePieChart({super.key, required this.leaves});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 🔥 Clamp negative values to 0 for display
    final sanitizedLeaves = leaves
        .map((l) => l.available < 0 ? 0.0 : l.available)
        .toList();

    final totalAvailable = sanitizedLeaves.fold<double>(0, (s, v) => s + v);

    if (totalAvailable <= 0) {
      return Card(
        elevation: 6,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const SizedBox(
          height: 280,
          child: Center(child: Text("No leave balance available")),
        ),
      );
    }

    return Card(
      elevation: 6,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  sections: List.generate(leaves.length, (index) {
                    final leave = leaves[index];
                    final value = leave.available < 0 ? 0.0 : leave.available;

                    final percent = (value / totalAvailable) * 100;

                    return PieChartSectionData(
                      value: value,
                      color: LeaveColorMapper.colorFor(leave.name),
                      radius: 40,
                      title: value == 0 ? "" : '${percent.toStringAsFixed(0)}%',
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimary,
                      ),
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Available",
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalAvailable.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Days",
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
