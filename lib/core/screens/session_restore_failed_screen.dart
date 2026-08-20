import 'package:flutter/material.dart';

class SessionRestoreFailedScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isLoading;

  const SessionRestoreFailedScreen({
    super.key,
    required this.onRetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/hrms_logo_2.png',
                height: 72,
              ),
              const SizedBox(height: 28),
              Text(
                'Could not restore your session',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Check your internet connection and try again. You have not been logged out.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onRetry,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
