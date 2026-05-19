import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isActive;
  final int index;
  final Widget? trailing;

  const DrawerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.index,
    this.isActive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final tileRadius = BorderRadius.circular(isIOS ? 12 : 14);

    final bgColor = isActive
        ? scheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;

    final iconColor = isActive ? scheme.primary : scheme.onSurfaceVariant;

    final textColor = isActive ? scheme.primary : scheme.onSurface;

    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Material(
            color: bgColor,
            borderRadius: tileRadius,
            child: InkWell(
              borderRadius: tileRadius,
              splashFactory: isIOS
                  ? NoSplash.splashFactory
                  : InkSplash.splashFactory,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: (index * 50).ms)
        .fade(duration: 300.ms)
        .slideX(begin: -.12, end: 0, curve: Curves.easeOutCubic);
  }
}
