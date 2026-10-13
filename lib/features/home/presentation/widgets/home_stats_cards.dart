import 'package:flutter/material.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class HomeStatsCards extends StatelessWidget {
  final HomeDashboardModel dashboard;

  const HomeStatsCards({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final stats = dashboard.stats;
    final leaveRemaining = stats.leavesRemaining;
    final leaveTotal =
        stats.leavesTotal <= 0 ? leaveRemaining : stats.leavesTotal;
    final leaveProgress =
        leaveTotal <= 0 ? 0.0 : (leaveRemaining / leaveTotal).clamp(0.0, 1.0);

    final cards = [
      _StatCardData(
        icon: Icons.eco_rounded,
        iconBg: HomeDashColors.softGreen,
        iconColor: HomeDashColors.accentGreen,
        title: 'Leaves Remaining',
        value: leaveTotal > 0
            ? '${_fmt(leaveRemaining)} / ${_fmt(leaveTotal)}'
            : _fmt(leaveRemaining),
        progress: leaveProgress,
        progressColor: HomeDashColors.accentGreen,
        onTap: () => Navigator.of(context).pushNamed('/leave-balance'),
      ),
      _StatCardData(
        icon: Icons.access_time_filled_rounded,
        iconBg: HomeDashColors.softPurple,
        iconColor: HomeDashColors.accentPurple,
        title: 'Worked Hours',
        value: '${stats.weekWorkedHours.toStringAsFixed(1)} hrs',
        footerIcon: Icons.schedule_rounded,
        footer: 'This Week',
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _StatMiniCard(data: cards[index]),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _StatCardData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final double? progress;
  final Color? progressColor;
  final String? footer;
  final IconData? footerIcon;
  final VoidCallback? onTap;

  const _StatCardData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    this.progress,
    this.progressColor,
    this.footer,
    this.footerIcon,
    this.onTap,
  });
}

class _StatMiniCard extends StatelessWidget {
  final _StatCardData data;

  const _StatMiniCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 148,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeDashColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: HomeDashColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: data.iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data.icon, size: 18, color: data.iconColor),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: HomeDashColors.muted.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: HomeDashColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeDashColors.title,
                ),
              ),
              const Spacer(),
              if (data.progress != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.progress,
                    minHeight: 5,
                    backgroundColor: HomeDashColors.softGreen,
                    color: data.progressColor ?? HomeDashColors.accentGreen,
                  ),
                )
              else if (data.footer != null)
                Row(
                  children: [
                    Icon(
                      data.footerIcon ?? Icons.calendar_today_rounded,
                      size: 11,
                      color: HomeDashColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.footer!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: HomeDashColors.muted,
                        fontWeight: FontWeight.w500,
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
