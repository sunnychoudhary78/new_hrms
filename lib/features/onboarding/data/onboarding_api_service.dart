import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/network/api_service.dart';
import 'package:lms/features/onboarding/data/models/day_one_models.dart';

class OnboardingApiService {
  final ApiService api;

  OnboardingApiService(this.api);

  Future<OnboardingMe> getMyOnboarding() async {
    final res = await api.get(ApiEndpoints.onboardingMe);
    return OnboardingMe.fromJson(_asMap(res));
  }

  Future<OnboardingMe> syncMyOnboarding() async {
    final res = await api.post(ApiEndpoints.onboardingMeSync, {});
    return OnboardingMe.fromJson(_asMap(res));
  }

  Future<OnboardingMe> completeDayOneStep(String key) async {
    final res = await api.post(ApiEndpoints.onboardingDayOneComplete(key), {});
    return OnboardingMe.fromJson(_asMap(res));
  }

  Future<void> changePasswordFirstLogin({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.post(ApiEndpoints.onboardingChangePassword, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Map<String, dynamic>? _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }
}
