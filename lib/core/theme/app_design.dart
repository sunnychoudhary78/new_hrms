import 'package:flutter/material.dart';

/// Design tokens. Surface / text / primary adapt to the active [ThemeData]
/// after [AppColors.bindFromTheme] runs (see [MaterialApp.builder]).
class AppColors {
  AppColors._();

  // Brand fallbacks (used before bind + as ThemeData seed defaults)
  static const heroStart = Color(0xFF5B6CF5);
  static const heroEnd = Color(0xFF6B7CFA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const accentPurple = Color(0xFF8B5CF6);
  static const statusGreen = success;
  static const statusOrange = warning;
  static const statusRed = danger;
  static const statusDeepOrange = Color(0xFFEA580C);
  static const draft = Color(0xFF94A3B8);
  static const softBlueStart = Color(0xFFDBEAFE);
  static const softBlueEnd = Color(0xFFE0E7FF);
  static const softBlueMid = Color(0xFFBFDBFE);

  // Light surfaces
  static const lightBg = Color(0xFFF3F6FB);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTitle = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightSoftFill = Color(0xFFF8FAFC);
  static const lightIconBg = Color(0xFFEEF2FF);

  // Dark surfaces — soft elevated slate (readable, not near-black)
  static const darkBg = Color(0xFF1A2232);
  static const darkCard = Color(0xFF2A3447);
  static const darkTitle = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFFB4C0D0);
  static const darkBorder = Color(0xFF3E4B61);
  static const darkSoftFill = Color(0xFF232D40);
  static const darkIconBg = Color(0xFF354358);

  static Brightness _brightness = Brightness.light;
  static ColorScheme? _scheme;

  /// Call from [MaterialApp.builder] with the resolved light/dark theme.
  static void bindFromTheme(ThemeData theme) {
    _brightness = theme.brightness;
    _scheme = theme.colorScheme;
  }

  static bool get isDark => _brightness == Brightness.dark;

  static Color get bg => isDark ? darkBg : lightBg;
  static Color get card => isDark ? darkCard : lightCard;
  static Color get title => isDark ? darkTitle : lightTitle;
  static Color get muted => isDark ? darkMuted : lightMuted;
  static Color get border => isDark ? darkBorder : lightBorder;
  static Color get softFill => isDark ? darkSoftFill : lightSoftFill;
  static Color get iconBg => isDark ? darkIconBg : lightIconBg;

  /// Follows Theme Settings seed via [ColorScheme.primary].
  static Color get primary => _scheme?.primary ?? heroStart;
  static Color get primaryEnd =>
      Color.lerp(primary, isDark ? Colors.white : heroEnd, isDark ? 0.15 : 0.35) ??
      primary;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: (isDark ? const Color(0xFF020617) : const Color(0xFF0F172A))
              .withValues(alpha: isDark ? 0.22 : 0.06),
          blurRadius: isDark ? 14 : 18,
          offset: Offset(0, isDark ? 6 : 8),
        ),
      ];

  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryEnd],
      );

  static LinearGradient get softHeroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                primary.withValues(alpha: 0.38),
                primary.withValues(alpha: 0.20),
              ]
            : [
                Color.lerp(softBlueStart, primary, 0.15)!,
                Color.lerp(softBlueEnd, primary, 0.10)!,
              ],
      );

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'partiallyapproved':
      case 'manager approved':
      case 'hod approved':
      case 'processed':
      case 'published':
        return success;
      case 'rejected':
      case 'revoked':
      case 'cancelled':
      case 'expired':
        return danger;
      case 'pending':
        return warning;
      case 'draft':
        return draft;
      case 'revocationrequested':
        return statusDeepOrange;
      default:
        return primary;
    }
  }

  static BoxDecoration heroDecoration({double radius = AppRadius.lg}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: heroGradient,
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    double radius = AppRadius.lg,
    bool highlighted = false,
  }) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? primary.withValues(alpha: 0.35) : border,
        ),
        boxShadow: cardShadow,
      );
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const pill = 50.0;
}

class AppElevation {
  static const card = 2.0;
}

/// Global ThemeData so every screen inherits one professional look.
class AppTheme {
  static ThemeData light(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      surface: AppColors.lightCard,
    ).copyWith(
      surfaceContainerLowest: AppColors.lightBg,
      surfaceContainerLow: AppColors.lightSoftFill,
      outline: AppColors.lightBorder,
      onSurface: AppColors.lightTitle,
      onSurfaceVariant: AppColors.lightMuted,
    );

    return _base(scheme, seed, Brightness.light);
  }

  static ThemeData dark(Color seed) {
    // Keep brand primary vivid; lift surfaces so UI never feels "ink black".
    final vividPrimary = Color.lerp(seed, Colors.white, 0.08) ?? seed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: vividPrimary,
      surface: AppColors.darkCard,
    ).copyWith(
      primary: vividPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color.lerp(vividPrimary, AppColors.darkCard, 0.55)!,
      onPrimaryContainer: const Color(0xFFE8EEFF),
      secondary: Color.lerp(vividPrimary, const Color(0xFF94A3B8), 0.35)!,
      onSecondary: Colors.white,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkTitle,
      onSurfaceVariant: AppColors.darkMuted,
      surfaceContainerLowest: AppColors.darkBg,
      surfaceContainerLow: AppColors.darkSoftFill,
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHigh: AppColors.darkIconBg,
      surfaceContainerHighest: Color.lerp(
        AppColors.darkIconBg,
        Colors.white,
        0.06,
      )!,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder.withValues(alpha: 0.75),
      scrim: const Color(0xFF020617).withValues(alpha: 0.45),
      shadow: const Color(0xFF020617),
      inverseSurface: const Color(0xFFE2E8F0),
      onInverseSurface: const Color(0xFF1A2232),
    );

    return _base(scheme, vividPrimary, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Color seed, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final title = isDark ? AppColors.darkTitle : AppColors.lightTitle;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final softFill = isDark ? AppColors.darkSoftFill : AppColors.lightSoftFill;
    final divider = isDark ? border.withValues(alpha: 0.85) : border;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: divider,
      splashFactory:
          isDark ? InkRipple.splashFactory : InkSplash.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: title,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: title,
        ),
        iconTheme: IconThemeData(color: title, size: 24),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.darkSoftFill : bg,
        surfaceTintColor: Colors.transparent,
        scrimColor: isDark
            ? const Color(0xFF020617).withValues(alpha: 0.45)
            : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isDark ? border.withValues(alpha: 0.9) : border,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(
            color: isDark
                ? scheme.primary.withValues(alpha: 0.85)
                : scheme.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softFill,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: title),
        secondaryLabelStyle: TextStyle(color: title),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        dragHandleColor: muted.withValues(alpha: 0.55),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: scheme.primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: title,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : muted,
            size: 24,
          );
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: title, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkIconBg : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkTitle : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: title,
        tileColor: Colors.transparent,
        selectedTileColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isDark ? AppColors.darkMuted : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35);
          }
          return isDark ? AppColors.darkBorder : null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: muted, width: 1.6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: isDark ? 2 : 4,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: muted,
        indicatorColor: scheme.primary,
        dividerColor: divider,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: softFill,
        circularTrackColor: softFill,
      ),
      iconTheme: IconThemeData(color: title),
      // Keep seed available for widgets that read primary directly
      primaryColor: seed,
    );
  }
}
