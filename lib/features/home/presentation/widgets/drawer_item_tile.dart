import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isActive;
  final int index;
  final Widget? trailing;
  final Color? accent;
  final bool showChevron;
  final String? subtitle;

  const DrawerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.index,
    this.isActive = false,
    this.trailing,
    this.accent,
    this.showChevron = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final tileRadius = BorderRadius.circular(14);
    final color = accent ?? HomeDashColors.accentBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: tileRadius,
        child: InkWell(
          borderRadius: tileRadius,
          splashFactory:
              isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: tileRadius,
              border: isActive
                  ? Border.all(color: color.withValues(alpha: 0.18))
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
              child: Row(
                children: [
                  // Active indicator bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 3.5,
                    height: subtitle != null ? 36 : 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isActive ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? color : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w600,
                            color: isActive ? color : HomeDashColors.title,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: HomeDashColors.muted.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (showChevron)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isActive
                          ? color.withValues(alpha: 0.8)
                          : HomeDashColors.muted.withValues(alpha: 0.45),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
