import 'package:flutter/material.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class AttendanceSummaryGrid extends StatelessWidget {
  final AttendanceSummary summary;
  final List<String> holidayLabels;
  final ValueChanged<String>? onTapStatus;

  const AttendanceSummaryGrid({
    super.key,
    required this.summary,
    this.holidayLabels = const [],
    this.onTapStatus,
  });

  String _formatNumber(num value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final dash = HomeDashColors.of(context);
    final items = [
      _StatItem(
        keyName: 'present',
        title: 'Present',
        value: _formatNumber(summary.workingDays),
        icon: Icons.check_circle_rounded,
        accent: HomeDashColors.accentGreen,
        soft: dash.softGreen,
      ),
      _StatItem(
        keyName: 'late',
        title: 'Late',
        value: '${summary.lateDays}',
        icon: Icons.schedule_rounded,
        accent: HomeDashColors.accentOrange,
        soft: dash.softOrange,
      ),
      _StatItem(
        keyName: 'absent',
        title: 'Absent',
        value: _formatNumber(summary.absentDays),
        icon: Icons.cancel_rounded,
        accent: HomeDashColors.accentRed,
        soft: HomeDashColors.accentRed.withValues(alpha: dash.isDark ? 0.28 : 0.12),
      ),
      _StatItem(
        keyName: 'leave',
        title: 'Leave',
        value: _formatNumber(summary.totalLeaves),
        icon: Icons.beach_access_rounded,
        accent: const Color(0xFF8B5CF6),
        soft: dash.softPurple,
      ),
      _StatItem(
        keyName: 'holiday',
        title: 'Holiday',
        value: '${summary.totalHolidays}',
        icon: Icons.celebration_rounded,
        accent: dash.accentBlue,
        soft: dash.softBlue,
      ),
      _StatItem(
        keyName: 'weekoff',
        title: 'Week Off',
        value: '${summary.totalWeekoffs}',
        icon: Icons.weekend_rounded,
        accent: const Color(0xFF6366F1),
        soft: const Color(0xFF6366F1).withValues(alpha: dash.isDark ? 0.28 : 0.12),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PillStatCard(
                  item: items[i],
                  onTap: onTapStatus == null
                      ? null
                      : () => onTapStatus!(items[i].keyName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < items.length
                    ? _PillStatCard(
                        item: items[i + 1],
                        onTap: onTapStatus == null
                            ? null
                            : () => onTapStatus!(items[i + 1].keyName),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatItem {
  final String keyName;
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Color soft;

  const _StatItem({
    required this.keyName,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.soft,
  });
}

class _PillStatCard extends StatelessWidget {
  final _StatItem item;
  final VoidCallback? onTap;

  const _PillStatCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dash = HomeDashColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: dash.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
            boxShadow: dash.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 18, color: item.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dash.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: item.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: dash.muted.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
