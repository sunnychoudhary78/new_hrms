import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalSuccess extends StatelessWidget {
  final String message;

  const GlobalSuccess({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        /// Blur background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),

        /// Success card
        Center(
          child: Material(
            color: Colors.transparent,
            child:
                ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withOpacity(0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// Keep the animation inside a square box so it does
                            /// not stretch into a wide rectangle on large screens.
                            SizedBox.square(
                              dimension: 120,
                              child: Lottie.asset(
                                "assets/animations/success.json",
                                fit: BoxFit.contain,
                                repeat: false,
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// Message
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(),
          ),
        ),
      ],
    );
  }
}
