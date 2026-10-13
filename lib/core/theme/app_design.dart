import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF3F6FB);
  static const card = Colors.white;
  static const title = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static const heroStart = Color(0xFF5B6CF5);
  static const heroEnd = Color(0xFF6B7CFA);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const accentPurple = Color(0xFF8B5CF6);

  static const primary = heroStart;
  static const primaryEnd = heroEnd;

  static const softBlueStart = Color(0xFFDBEAFE);
  static const softBlueEnd = Color(0xFFE0E7FF);
  static const softBlueMid = Color(0xFFBFDBFE);

  static const statusGreen = success;
  static const statusOrange = warning;
  static const statusRed = danger;
  static const statusDeepOrange = Color(0xFFEA580C);
  static const draft = Color(0xFF94A3B8);
  static const softFill = Color(0xFFF8FAFC);
  static const iconBg = Color(0xFFEEF2FF);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heroStart, heroEnd],
      );

  static LinearGradient get softHeroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [softBlueStart, softBlueEnd],
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
          color: heroStart.withValues(alpha: 0.28),
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
      surface: AppColors.card,
    ).copyWith(
      surfaceContainerLowest: AppColors.bg,
      outline: AppColors.border,
      onSurface: AppColors.title,
      onSurfaceVariant: AppColors.muted,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.title,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.title,
        ),
        iconTheme: const IconThemeData(color: AppColors.title, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.softFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.title,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.softFill,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData dark(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
