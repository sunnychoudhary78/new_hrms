import 'package:flutter/material.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.event_note_rounded,
        label: 'Apply Leave',
        iconColor: HomeDashColors.accentPurple,
        iconBg: HomeDashColors.softPurple,
        onTap: () => Navigator.of(context).pushNamed('/leave-apply'),
      ),
      _QuickAction(
        icon: Icons.sync_rounded,
        label: 'View Attendance',
        iconColor: HomeDashColors.accentBlue,
        iconBg: HomeDashColors.softBlue,
        onTap: () => Navigator.of(context).pushNamed('/view-attendance'),
      ),
      _QuickAction(
        icon: Icons.description_outlined,
        label: 'Payslip',
        iconColor: HomeDashColors.accentOrange,
        iconBg: HomeDashColors.softOrange,
        onTap: () => Navigator.of(context).pushNamed('/payslip'),
      ),
      _QuickAction(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        iconColor: HomeDashColors.accentGreen,
        iconBg: HomeDashColors.softGreen,
        onTap: () => Scaffold.of(context).openDrawer(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: HomeDashColors.title,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _QuickActionTile(action: actions[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: HomeDashColors.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: HomeDashColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon,
                  size: 22,
                  color: action.iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: HomeDashColors.title,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
