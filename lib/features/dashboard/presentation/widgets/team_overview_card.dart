import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../../data/models/team_dashboard_model.dart';

class TeamOverviewCard extends StatelessWidget {
  final TeamDashboard dashboard;

  const TeamOverviewCard({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final attendancePercentage = dashboard.total == 0
        ? 0
        : (dashboard.present / dashboard.total) * 100;

    /// 🔥 MUCH SMALLER DONUT
    final donutSize = screenWidth < 380 ? 42.0 : 55.0;

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ================= LEFT SIDE =================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Team Health Overview",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "${attendancePercentage.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "Attendance Rate",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _statChip(
                      context,
                      label: "Present",
                      value: dashboard.present,
                      color: AppColors.success,
                    ),
                    _statChip(
                      context,
                      label: "Absent",
                      value: dashboard.absent,
                      color: AppColors.danger,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  "Total Employees: ${dashboard.total}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          /// ================= RIGHT SIDE =================
          Padding(
            padding: EdgeInsets.only(right: 15, top: 15),
            child: SizedBox(
              width: donutSize + 24,
              child: Column(
                children: [
                  /// 🔵 SMALL DONUT
                  SizedBox(
                    width: donutSize,
                    height: donutSize,
                    child: Padding(
                      padding: EdgeInsetsGeometry.all(15),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius:
                                  donutSize * 0.65, // thinner ring
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  value: dashboard.present.toDouble(),
                                  color: AppColors.success,
                                  showTitle: false,
                                  radius: donutSize * 0.42,
                                ),
                                PieChartSectionData(
                                  value: dashboard.absent.toDouble(),
                                  color: AppColors.danger,
                                  showTitle: false,
                                  radius: donutSize * 0.42,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${attendancePercentage.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// 🔥 PUSH GRAPH LOWER
                  const SizedBox(height: 50),

                  /// 📈 MINI 7 DAY TREND
                  SizedBox(
                    width: donutSize + 20,
                    height: 50,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: dashboard.total.toDouble(),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              dashboard.lastSevenDays.length,
                              (i) => FlSpot(
                                i.toDouble(),
                                dashboard.lastSevenDays[i].present.toDouble(),
                              ),
                            ),
                            isCurved: true,
                            barWidth: 2,
                            color: AppColors.primary,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary.withOpacity(.25),
                                  scheme.primary.withOpacity(.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    BuildContext context, {
    required String label,
    required int value,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
