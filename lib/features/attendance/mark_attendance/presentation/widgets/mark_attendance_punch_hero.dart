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
    final dash = HomeDashColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final punchLabel = isCheckedIn ? 'Punch Out' : 'Punch In';
    // Punch In = green, Punch Out = red
    final colors = isCheckedIn
        ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
        : const [Color(0xFF22C55E), Color(0xFF16A34A)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: dash.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
        boxShadow: dash.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            _greeting,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: dash.title,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: canPunch
                ? () {
                    HapticFeedback.lightImpact();
                    onPunch?.call();
                  }
                : null,
            child: SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(168, 168),
                    painter: _RingPainter(
                      progress: isCheckedIn ? progress.clamp(0.05, 1.0) : 0.12,
                      color: colors.first,
                    ),
                  ),
                  Container(
                    width: 132,
                    height: 132,
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
                                color: colors.first.withValues(alpha: 0.32),
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
                          size: 40,
                          color: Colors.white.withValues(
                            alpha: canPunch ? 1 : 0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          punchLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: canPunch ? 1 : 0.75,
                            ),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCheckedIn ? dash.softGreen : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.35),
              ),
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
                        : dash.muted,
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
                        : dash.muted,
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
      ..color = const Color(0xFFE2E8F0)
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
