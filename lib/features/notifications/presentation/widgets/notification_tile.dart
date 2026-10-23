import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  static const _teal = Color(0xFF0F766E);
  static const _mint = Color(0xFFE0F2F1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = BorderRadius.circular(isIOS ? 14 : 16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black).withValues(
                  alpha: isDark ? 0.18 : 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? _teal.withValues(alpha: 0.22)
                        : _mint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? const Color(0xFF5EEAD4) : _teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w600,
                          color: scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: scheme.outline.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
