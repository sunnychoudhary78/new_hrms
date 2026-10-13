import 'package:flutter/material.dart';

/// Soft pastel dashboard palette matching the home redesign.
class HomeDashColors {
  static const bg = Color(0xFFF3F6FB);
  static const card = Colors.white;
  static const title = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentGreen = Color(0xFF22C55E);
  static const accentPurple = Color(0xFF8B5CF6);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentRed = Color(0xFFEF4444);
  static const softBlue = Color(0xFFDBEAFE);
  static const softGreen = Color(0xFFDCFCE7);
  static const softPurple = Color(0xFFEDE9FE);
  static const softOrange = Color(0xFFFEF3C7);
  static const expected = Color(0xFF93C5FD);
  static const worked = Color(0xFF6366F1);
  static const overtime = Color(0xFF22C55E);
  static const capped = Color(0xFFFBBF24);
  static const leave = Color(0xFFF59E0B);
  static const absent = Color(0xFFEF4444);
  static const weekOff = Color(0xFF8B5CF6);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? HomeDashColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: HomeDashColors.cardShadow,
      ),
      child: child,
    );
  }
}
