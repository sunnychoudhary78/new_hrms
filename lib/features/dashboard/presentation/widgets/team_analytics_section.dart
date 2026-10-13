import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../../data/models/team_dashboard_model.dart';

class TeamAnalyticsSection extends StatelessWidget {
  final TeamDashboard dashboard;

  const TeamAnalyticsSection({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopFiveEfficiencyChart(dashboard: dashboard),
        const SizedBox(height: 28),
        _TeamComparisonChart(dashboard: dashboard),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////
/// 1️⃣ TOP 5 — DAILY PRODUCTIVITY %
////////////////////////////////////////////////////////////////

class _TopFiveEfficiencyChart extends StatelessWidget {
  final TeamDashboard dashboard;

  const _TopFiveEfficiencyChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const standardDayMinutes = 9 * 60;

    final employees =
        dashboard.employees.where((e) => e.attendanceSummary != null).map((e) {
          final summary = e.attendanceSummary!;

          double productivity = 0;

          if (summary.workingDays > 0) {
            final avgMinutes = summary.totalMinutes / summary.workingDays;
            productivity = (avgMinutes / standardDayMinutes) * 100;
          }

          final imageUrl =
              (e.profilePicture != null && e.profilePicture!.isNotEmpty)
              ? (e.profilePicture!.startsWith("http")
                    ? e.profilePicture!
                    : "${ApiConstants.imageBaseUrl}${e.profilePicture}")
              : '';

          return _EmployeeEfficiency(
            id: e.employeeId,
            efficiency: productivity.clamp(0.0, 120.0),
            profileUrl: imageUrl,
          );
        }).toList()..sort((a, b) => b.efficiency.compareTo(a.efficiency));

    final top5 = employees.take(5).toList();

    return _cardWrapper(
      context,
      title: "Top 5 – Daily Productivity %",
      child: SizedBox(
        height: 230,
        child: BarChart(
          BarChartData(
            maxY: 120,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),

            gridData: FlGridData(
              show: true,
              horizontalInterval: 20,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: scheme.outlineVariant.withOpacity(.2),
                strokeWidth: 0.8,
              ),
            ),

            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    if (value % 20 != 0) return const SizedBox();
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),

              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 55,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= top5.length) {
                      return const SizedBox();
                    }

                    final emp = top5[index];

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.surfaceContainerHighest,
                        backgroundImage: emp.profileUrl.isNotEmpty
                            ? NetworkImage(emp.profileUrl)
                            : null,
                        child: emp.profileUrl.isEmpty
                            ? Text(
                                emp.id.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),

              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),

            barGroups: List.generate(top5.length, (index) {
              final emp = top5[index];

              Color barColor;

              if (emp.efficiency >= 100) {
                barColor = AppColors.primary;
              } else if (emp.efficiency >= 80) {
                barColor = AppColors.success;
              } else if (emp.efficiency >= 60) {
                barColor = AppColors.warning;
              } else {
                barColor = AppColors.danger;
              }

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: emp.efficiency,
                    width: 22,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    color: barColor,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// 2️⃣ MONTHLY TEAM COMPARISON — HORIZONTAL
////////////////////////////////////////////////////////////////

class _TeamComparisonChart extends StatelessWidget {
  final TeamDashboard dashboard;

  const _TeamComparisonChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final summaries = dashboard.employees
        .map((e) => e.attendanceSummary)
        .whereType<dynamic>()
        .toList();

    final totalMinutes = summaries.fold<double>(
      0.0,
      (sum, s) => sum + (s.totalMinutes as num).toDouble(),
    );

    final totalExpectedHours = summaries.fold<double>(
      0.0,
      (sum, s) => sum + (s.expectedWorkingHours as num).toDouble(),
    );

    final totalActualHours = totalMinutes / 60;

    final maxHours = totalExpectedHours > totalActualHours
        ? totalExpectedHours
        : totalActualHours;

    return _cardWrapper(
      context,
      title: "Monthly Team Work Comparison",
      child: SizedBox(
        height: 120,
        child: Column(
          children: [
            _horizontalBar(
              context,
              label: "Expected",
              value: totalExpectedHours,
              maxValue: maxHours,
              color: scheme.outline,
            ),
            const SizedBox(height: 20),
            _horizontalBar(
              context,
              label: "Actual",
              value: totalActualHours,
              maxValue: maxHours,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryEnd],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _horizontalBar(
    BuildContext context, {
    required String label,
    required double value,
    required double maxValue,
    Color? color,
    Gradient? gradient,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final percent = maxValue == 0 ? 0.0 : value / maxValue;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "${value.toStringAsFixed(0)}h",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////
/// CARD WRAPPER
////////////////////////////////////////////////////////////////

Widget _cardWrapper(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return PremiumCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.title,
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _EmployeeEfficiency {
  final String id;
  final double efficiency;
  final String profileUrl;

  const _EmployeeEfficiency({
    required this.id,
    required this.efficiency,
    required this.profileUrl,
  });
}
