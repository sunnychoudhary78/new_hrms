import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';

/// Theme-resolved dashboard colors for a given [BuildContext].
class HomeDashPalette {
  final Color bg;
  final Color card;
  final Color title;
  final Color muted;
  final Color accentBlue;
  final Color softBlue;
  final Color softGreen;
  final Color softPurple;
  final Color softOrange;
  final Color expected;
  final Color worked;
  final List<BoxShadow> cardShadow;
  final bool isDark;

  const HomeDashPalette({
    required this.bg,
    required this.card,
    required this.title,
    required this.muted,
    required this.accentBlue,
    required this.softBlue,
    required this.softGreen,
    required this.softPurple,
    required this.softOrange,
    required this.expected,
    required this.worked,
    required this.cardShadow,
    required this.isDark,
  });
}

/// Soft pastel dashboard palette.
/// Use [HomeDashColors.of] in widgets so Light/Dark always matches [ThemeData].
class HomeDashColors {
  HomeDashColors._();

  static const accentGreen = Color(0xFF22C55E);
  static const accentPurple = Color(0xFF8B5CF6);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentRed = Color(0xFFEF4444);
  static const overtime = Color(0xFF22C55E);
  static const capped = Color(0xFFFBBF24);
  static const leave = Color(0xFFF59E0B);
  static const absent = Color(0xFFEF4444);
  static const weekOff = Color(0xFF8B5CF6);

  /// Theme-synced palette for the current [BuildContext].
  static HomeDashPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final primary = scheme.primary;

    // Keep AppColors bind in sync for leftover static usages.
    AppColors.bindFromTheme(theme);

    return HomeDashPalette(
      bg: scheme.surfaceContainerLowest,
      card: scheme.surface,
      title: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      accentBlue: primary,
      softBlue: dark
          ? primary.withValues(alpha: 0.30)
          : Color.lerp(const Color(0xFFDBEAFE), primary, 0.12)!,
      softGreen: dark
          ? accentGreen.withValues(alpha: 0.28)
          : const Color(0xFFDCFCE7),
      softPurple: dark
          ? accentPurple.withValues(alpha: 0.28)
          : const Color(0xFFEDE9FE),
      softOrange: dark
          ? accentOrange.withValues(alpha: 0.28)
          : const Color(0xFFFEF3C7),
      expected: dark
          ? primary.withValues(alpha: 0.55)
          : const Color(0xFF93C5FD),
      worked: primary,
      cardShadow: [
        BoxShadow(
          color: (dark ? const Color(0xFF020617) : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.20 : 0.06),
          blurRadius: dark ? 14 : 18,
          offset: Offset(0, dark ? 6 : 8),
        ),
      ],
      isDark: dark,
    );
  }

  // Back-compat static getters (use after of()/bind)
  static Color get bg => AppColors.bg;
  static Color get card => AppColors.card;
  static Color get title => AppColors.title;
  static Color get muted => AppColors.muted;
  static Color get accentBlue => AppColors.primary;
  static Color get softBlue => AppColors.isDark
      ? AppColors.primary.withValues(alpha: 0.30)
      : Color.lerp(const Color(0xFFDBEAFE), AppColors.primary, 0.12)!;
  static Color get softGreen => AppColors.isDark
      ? accentGreen.withValues(alpha: 0.28)
      : const Color(0xFFDCFCE7);
  static Color get softPurple => AppColors.isDark
      ? accentPurple.withValues(alpha: 0.28)
      : const Color(0xFFEDE9FE);
  static Color get softOrange => AppColors.isDark
      ? accentOrange.withValues(alpha: 0.28)
      : const Color(0xFFFEF3C7);
  static Color get expected => AppColors.isDark
      ? AppColors.primary.withValues(alpha: 0.55)
      : const Color(0xFF93C5FD);
  static Color get worked => AppColors.primary;
  static List<BoxShadow> get cardShadow => AppColors.cardShadow;
}

class HomeDashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const HomeDashCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dash = HomeDashColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? dash.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outline.withValues(alpha: dash.isDark ? 0.75 : 0.45),
        ),
        boxShadow: dash.cardShadow,
      ),
      child: child,
    );
  }
}
