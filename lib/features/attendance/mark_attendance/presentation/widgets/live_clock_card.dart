import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LiveClockCard extends StatelessWidget {
  final String workingTime;
  final double progress;
  final TimeOfDay? shiftStart;
  final TimeOfDay? shiftEnd;
  final bool isCheckedIn;

  const LiveClockCard({
    super.key,
    required this.workingTime,
    required this.progress,
    required this.shiftStart,
    required this.shiftEnd,
    required this.isCheckedIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(isIOS ? 22 : 30),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isIOS ? 0.05 : 0.08),
            blurRadius: isIOS ? 14 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShiftLabel(
                title: "Shift Start",
                time: shiftStart?.format(context) ?? "--:--",
              ),
              _ShiftLabel(
                title: "Shift End",
                time: shiftEnd?.format(context) ?? "--:--",
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final arcWidth = width * 0.75;
              final arcHeight = arcWidth / 2;

              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: arcWidth,
                    height: arcHeight,
                    child: CustomPaint(
                      painter: _ModernArcPainter(progress, scheme.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Column(
                      children: [
                        Text(
                          workingTime,
                          style: TextStyle(
                            fontSize: arcWidth * 0.14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCheckedIn ? "Working hours" : "Not punched in",

                          style: TextStyle(
                            fontSize: arcWidth * 0.07,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShiftLabel extends StatelessWidget {
  final String title;
  final String time;

  const _ShiftLabel({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: title == "Shift Start"
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ModernArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ModernArcPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);

    final basePaint = Paint()
      ..color = Colors.grey.withOpacity(.12)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, basePaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [color, color.withOpacity(.6)],
        ).createShader(rect);

      canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress.clamp(0, 1),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ModernArcPainter old) =>
      old.progress != progress;
}
