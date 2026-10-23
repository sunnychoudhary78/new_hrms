import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final tileRadius = BorderRadius.circular(14);
    final color = accent ?? scheme.primary;
    final idleIconBg = scheme.surfaceContainerLow;
    final idleIconFg = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isActive ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: tileRadius,
        child: InkWell(
          borderRadius: tileRadius,
          splashFactory:
              isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3.5,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive ? color : idleIconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : idleIconFg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive ? color : scheme.onSurface,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isActive
                        ? color.withValues(alpha: 0.75)
                        : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
