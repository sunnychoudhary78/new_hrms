import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class MarkAttendancePunchHero extends StatelessWidget {
  final bool isCheckedIn;
  final bool canPunch;
  final double progress;
  final VoidCallback? onPunch;

  const MarkAttendancePunchHero({
    super.key,
    required this.isCheckedIn,
    required this.canPunch,
    required this.progress,
    required this.onPunch,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    final punchLabel = isCheckedIn ? 'Punch Out' : 'Punch In';
    final colors = isCheckedIn
        ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
        : const [Color(0xFF6366F1), Color(0xFF8B5CF6)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: HomeDashColors.cardShadow,
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HomeDashColors.softPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: HomeDashColors.accentPurple,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _greeting,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HomeDashColors.title,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Let's make it a productive day",
                style: TextStyle(
                  fontSize: 12,
                  color: HomeDashColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: canPunch
                ? () {
                    HapticFeedback.lightImpact();
                    onPunch?.call();
                  }
                : null,
            child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(148, 148),
                    painter: _RingPainter(
                      progress: isCheckedIn ? progress.clamp(0.05, 1.0) : 0.12,
                      color: colors.first,
                    ),
                  ),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: canPunch
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors,
                            )
                          : null,
                      color: canPunch ? null : const Color(0xFFCBD5E1),
                      boxShadow: canPunch
                          ? [
                              BoxShadow(
                                color: colors.first.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 36,
                          color: Colors.white.withValues(
                            alpha: canPunch ? 1 : 0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          punchLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: canPunch ? 1 : 0.75,
                            ),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Icon(
                          isCheckedIn
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 14,
                          color: Colors.white.withValues(
                            alpha: canPunch ? 0.9 : 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCheckedIn
                  ? HomeDashColors.softGreen
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCheckedIn
                        ? HomeDashColors.accentGreen
                        : HomeDashColors.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCheckedIn ? 'Punched in' : 'Not punched in',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCheckedIn
                        ? HomeDashColors.accentGreen
                        : HomeDashColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final base = Paint()
      ..color = const Color(0xFFE0E7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.2), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
