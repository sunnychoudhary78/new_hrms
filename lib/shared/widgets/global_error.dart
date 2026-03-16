import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalError extends StatelessWidget {
  final String message;

  const GlobalError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child:
              Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.error,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Row(
                          children: [
                            /// Icon Badge
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: scheme.onError.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: scheme.onError,
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 12),

                            /// Message
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: scheme.onError,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: -0.4, end: 0, curve: Curves.easeOutCubic)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                  ),
        ),
      ),
    );
  }
}
