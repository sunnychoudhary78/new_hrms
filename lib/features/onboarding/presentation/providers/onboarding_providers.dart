import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/onboarding/data/day_one_completion_store.dart';
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

final dayOneCompletionStoreProvider = Provider<DayOneCompletionStore>((ref) {
  return DayOneCompletionStore();
});

/// `true` once this user has finished every Day-one step at least once.
/// Starts as `true` so the guide entry points never flash before the stored
/// flag is read.
final dayOneFinishedProvider =
    NotifierProvider<DayOneFinishedNotifier, bool>(DayOneFinishedNotifier.new);

class DayOneFinishedNotifier extends Notifier<bool> {
  String _userId = '';

  @override
  bool build() {
    _userId = ref.watch(
      authProvider.select((auth) => auth.profile?.userId ?? ''),
    );
    _load(_userId);
    return true;
  }

  Future<void> _load(String userId) async {
    if (userId.isEmpty) {
      state = true;
      return;
    }

    final finished = await ref
        .read(dayOneCompletionStoreProvider)
        .isFinished(userId);

    // Ignore a late response for a user we already switched away from.
    if (_userId == userId) state = finished;
  }

  Future<void> markFinished() async {
    final userId = _userId;
    state = true;
    await ref.read(dayOneCompletionStoreProvider).markFinished(userId);
  }
}

/// Locks the guide as done the moment the last step completes.
void markDayOneFinishedIfComplete(WidgetRef ref, OnboardingMe data) {
  if (!data.dayOne.isComplete) return;
  if (ref.read(dayOneFinishedProvider)) return;
  ref.read(dayOneFinishedProvider.notifier).markFinished();
}

Future<void> syncOnboardingQuietly(Ref ref) async {
  try {
    final api = ref.read(onboardingApiServiceProvider);
    await api.syncMyOnboarding();
    ref.invalidate(myOnboardingProvider);
  } catch (_) {}
}
