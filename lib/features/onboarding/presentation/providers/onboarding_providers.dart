import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/onboarding/data/models/day_one_models.dart';
import 'package:lms/features/onboarding/data/onboarding_api_service.dart';

final onboardingApiServiceProvider = Provider<OnboardingApiService>((ref) {
  return OnboardingApiService(ref.read(apiServiceProvider));
});

final myOnboardingProvider = FutureProvider.autoDispose<OnboardingMe>((
  ref,
) async {
  final api = ref.read(onboardingApiServiceProvider);
  return api.getMyOnboarding();
});

Future<void> syncOnboardingQuietly(Ref ref) async {
  try {
    final api = ref.read(onboardingApiServiceProvider);
    await api.syncMyOnboarding();
    ref.invalidate(myOnboardingProvider);
  } catch (_) {}
}
