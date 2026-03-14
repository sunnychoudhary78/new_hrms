import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalMessage extends StatelessWidget {
  final String message;

  const GlobalMessage({super.key, required this.message});

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
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.green.shade600, // ✅ green background
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
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
