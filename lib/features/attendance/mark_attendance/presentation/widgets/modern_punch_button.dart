import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

class ModernPunchButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final List<Color> colors;

  const ModernPunchButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.colors,
  });

  @override
  State<ModernPunchButton> createState() => _ModernPunchButtonState();
}

class _ModernPunchButtonState extends State<ModernPunchButton> {
  bool _pressed = false;
  final AudioPlayer _player = AudioPlayer();

  Future<void> _playClick() async {
    await _player.play(AssetSource('sounds/tap.mpeg'));
  }

  List<Color> _darkenColors(List<Color> colors) {
    return colors.map((c) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
          .toColor();
    }).toList();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.onPressed == null;

    const double depth = 8;
    const double height = 64;
    const double radius = 22;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        if (!disabled) setState(() => _pressed = true);
      },
      onTapUp: (_) async {
        if (!disabled) {
          setState(() => _pressed = false);
          await _playClick();
          HapticFeedback.lightImpact();
          widget.onPressed?.call();
        }
      },
      onTapCancel: () {
        if (!disabled) setState(() => _pressed = false);
      },
      child: SizedBox(
        height: height + depth,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            /// 3D BASE SHADOW
            if (!disabled)
              Positioned(
                top: depth,
                left: depth * 0.3,
                right: -depth * 0.7,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      colors: _darkenColors(widget.colors),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

            /// MAIN BUTTON
            AnimatedPositioned(
              duration: 90.ms,
              curve: Curves.easeOut,
              top: _pressed ? depth : 0,
              left: 0,
              right: 0,
              child:
                  Container(
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: disabled
                              ? null
                              : LinearGradient(
                                  colors: widget.colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: disabled
                              ? scheme.surfaceContainerHighest
                              : null,
                          boxShadow: disabled
                              ? []
                              : _pressed
                              ? []
                              : [
                                  BoxShadow(
                                    color: widget.colors.first.withOpacity(.35),
                                    blurRadius: 18,
                                    offset: const Offset(4, 10),
                                  ),
                                ],
                        ),
                        child: Stack(
                          children: [
                            /// TOP HIGHLIGHT
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(radius),
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(.15),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            /// CONTENT WITH AUTO-SCALING TEXT (NO ELLIPSIS)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.icon,
                                      color: disabled
                                          ? scheme.onSurfaceVariant
                                          : scheme.onPrimary,
                                    ),

                                    const SizedBox(width: 10),

                                    /// AUTO SCALE TEXT
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          widget.text
                                              .replaceAll(
                                                'Check-in',
                                                'Check\u2011in',
                                              )
                                              .replaceAll(
                                                'Check-out',
                                                'Check\u2011out',
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.fade,
                                          softWrap: true,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: disabled
                                                ? scheme.onSurfaceVariant
                                                : scheme.onPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            height: 1.15,
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// BALANCER FOR PERFECT CENTER ALIGNMENT
                                    const SizedBox(width: 24),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(target: _pressed ? 1 : 0)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(0.96, 0.96),
                        duration: 90.ms,
                      )
                      .then()
                      .scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1, 1),
                        duration: 120.ms,
                        curve: Curves.easeOutBack,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
