import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_theme_provider.dart'; // adjust path if different

class NotificationTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    /// dynamic app theme color
    final primaryColor = ref.watch(appThemeProvider);

    final iconColor = _getIconColor(icon, primaryColor);
    final bgColor = _getBackgroundColor(icon, primaryColor, scheme);
    final iconBg = iconColor.withOpacity(.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isUnread ? bgColor : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? iconColor.withOpacity(.15)
              : scheme.outlineVariant.withOpacity(.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              /// UNREAD STRIPE
              if (isUnread)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ICON CONTAINER
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),

                      const SizedBox(width: 14),

                      /// TEXT CONTENT
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// TITLE
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: scheme.onSurface,
                                letterSpacing: .1,
                              ),
                            ),

                            const SizedBox(height: 6),

                            /// MESSAGE
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 8),

                            /// TIME (moved below, aligned right)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant.withOpacity(
                                    .8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 6),

                      /// CHEVRON
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: scheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ICON COLOR
  Color _getIconColor(IconData icon, Color primaryColor) {
    if (icon == Icons.login) return const Color(0xFF16A34A);
    if (icon == Icons.logout) return const Color(0xFFF59E0B);
    if (icon == Icons.timer_off) return const Color(0xFFDC2626);
    if (icon == Icons.edit_calendar) return const Color(0xFF7C3AED);
    if (icon == Icons.event_note) return const Color(0xFF2563EB);
    if (icon == Icons.check_circle) return const Color(0xFF059669);
    if (icon == Icons.warning) return const Color(0xFFEA580C);
    if (icon == Icons.home_work) return const Color(0xFF4F46E5);

    return primaryColor;
  }

  /// LIGHT BACKGROUND COLOR
  Color _getBackgroundColor(
    IconData icon,
    Color primaryColor,
    ColorScheme scheme,
  ) {
    if (icon == Icons.login) {
      return const Color(0xFF16A34A).withOpacity(.08);
    }

    if (icon == Icons.logout) {
      return const Color(0xFFF59E0B).withOpacity(.08);
    }

    if (icon == Icons.timer_off) {
      return const Color(0xFFDC2626).withOpacity(.08);
    }

    if (icon == Icons.edit_calendar) {
      return const Color(0xFF7C3AED).withOpacity(.08);
    }

    if (icon == Icons.event_note) {
      return const Color(0xFF2563EB).withOpacity(.08);
    }

    if (icon == Icons.check_circle) {
      return const Color(0xFF059669).withOpacity(.08);
    }

    if (icon == Icons.warning) {
      return const Color(0xFFEA580C).withOpacity(.08);
    }

    if (icon == Icons.home_work) {
      return const Color(0xFF4F46E5).withOpacity(.08);
    }

    return primaryColor.withOpacity(.06);
  }
}
