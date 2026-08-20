import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/effective_shift_model.dart';

class LiveClockCard extends StatelessWidget {
  final String workingTime;
  final double progress;
  final EffectiveShift? shift;
  final bool isCheckedIn;

  const LiveClockCard({
    super.key,
    required this.workingTime,
    required this.progress,
    required this.shift,
    required this.isCheckedIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final startSubtitle = shift?.startSubtitle ?? '';
    final lunch = shift?.lunchDisplay;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _ShiftLabel(
                  title: "Office start",
                  time: shift?.officeStartDisplay ?? "--:--",
                  subtitle: startSubtitle.isEmpty ? null : startSubtitle,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShiftLabel(
                  title: "Office end",
                  time: shift?.officeEndDisplay ?? "--:--",
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (lunch != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Lunch: $lunch",
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
  final String? subtitle;
  final bool alignEnd;

  const _ShiftLabel({
    required this.title,
    required this.time,
    this.subtitle,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
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
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
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
