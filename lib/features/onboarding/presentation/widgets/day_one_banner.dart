import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/onboarding/presentation/providers/onboarding_providers.dart';

class DayOneBanner extends ConsumerWidget {
  const DayOneBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOnboardingProvider);

    return async.maybeWhen(
      data: (data) {
        if (!data.showDashboardBanner) return const SizedBox.shrink();

        final dayOne = data.dayOne;
        final subtitle = dayOne.total > 0
            ? '${dayOne.completed} of ${dayOne.total} first-week steps done.'
            : 'Status: ${data.onboardingStatus.replaceAll('_', ' ')}. Finish your first-week steps so you are ready to work.';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: const Color(0xFFF0F9FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFBAE6FD)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your Day-one guide',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C4A6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/day-one'),
                      child: const Text('Open Day-one'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
