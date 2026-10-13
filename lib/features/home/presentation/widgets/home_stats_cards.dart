import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/shared/utils/overtime_estimate_utils.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class HomeStatsCards extends ConsumerWidget {
  final HomeDashboardModel dashboard;

  const HomeStatsCards({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = dashboard.stats;
    final leaveRemaining = stats.leavesRemaining;
    final leaveTotal =
        stats.leavesTotal <= 0 ? leaveRemaining : stats.leavesTotal;
    final leaveProgress =
        leaveTotal <= 0 ? 0.0 : (leaveRemaining / leaveTotal).clamp(0.0, 1.0);
    final weekHours = _liveWeekWorkedHours(ref, dashboard);

    final leaveValue = leaveTotal > 0 && leaveTotal != leaveRemaining
        ? '${_fmt(leaveRemaining)} / ${_fmt(leaveTotal)}'
        : _fmt(leaveRemaining);

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.eco_rounded,
            iconBg: HomeDashColors.softGreen,
            iconColor: HomeDashColors.accentGreen,
            title: 'Leave Balance',
            value: leaveValue,
            subtitle: 'days available',
            subtitleColor: HomeDashColors.accentGreen,
            progress: leaveProgress,
            onTap: () => Navigator.of(context).pushNamed('/leave-balance'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.nightlight_round,
            iconBg: HomeDashColors.softPurple,
            iconColor: HomeDashColors.accentPurple,
            title: 'Working Hours',
            value: '${weekHours.toStringAsFixed(1)} hrs',
            subtitle: 'This Week',
            subtitleColor: const Color(0xFF7C9CF0),
          ),
        ),
      ],
    );
  }

  double _liveWeekWorkedHours(WidgetRef ref, HomeDashboardModel dashboard) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    var minutes = 0;
    for (final bar in dashboard.lastFiveDays) {
      final day = DateTime(bar.date.year, bar.date.month, bar.date.day);
      if (day.isBefore(weekStart) || day.isAfter(weekEnd)) continue;
      if (day == today) continue;
      minutes += bar.workedMinutes;
    }

    final attendance = ref.watch(markAttendanceProvider).asData?.value;
    final sessions = attendance?.sessions ?? const [];
    final todayList = todaySessions(sessions);
    for (final s in todayList) {
      minutes += sessionWorkedMinutes(s);
    }
    final open = ref.watch(openSessionProvider(sessions));
    if (open != null &&
        sessionDateIso(open) == localTodayIso() &&
        !todayList.any((s) => s.id == open.id)) {
      minutes += sessionWorkedMinutes(open);
    }

    if (attendance == null) {
      for (final bar in dashboard.lastFiveDays) {
        final day = DateTime(bar.date.year, bar.date.month, bar.date.day);
        if (day == today) minutes += bar.workedMinutes;
      }
    }

    return double.parse((minutes / 60).toStringAsFixed(1));
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final double? progress;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeDashColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: HomeDashColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: HomeDashColors.muted.withValues(alpha: 0.7),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HomeDashColors.title,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: HomeDashColors.title,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: HomeDashColors.softGreen,
                    color: HomeDashColors.accentGreen,
                  ),
                ),
              ] else
                const SizedBox(height: 17),
            ],
          ),
        ),
      ),
    );
  }
}
