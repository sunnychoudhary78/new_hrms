import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';
import 'package:lms/features/attendance/shared/data/models/mobile_config_model.dart';

/// Provides latest mobile attendance config from backend
final mobileConfigProvider = FutureProvider.autoDispose<MobileConfig>((
  ref,
) async {
  final repo = ref.read(attendanceRepositoryProvider);

  final config = await repo.fetchMobileConfig();

  return config;
});

/// Selector: Can Check In
final canMobileCheckInProvider = Provider.autoDispose<bool>((ref) {
  final configAsync = ref.watch(mobileConfigProvider);

  return configAsync.maybeWhen(
    data: (config) => config.allowMobileCheckin,
    orElse: () => false,
  );
});

/// Selector: Can Check Out
final canMobileCheckOutProvider = Provider.autoDispose<bool>((ref) {
  final configAsync = ref.watch(mobileConfigProvider);

  return configAsync.maybeWhen(
    data: (config) => config.allowMobileCheckin,
    orElse: () => false,
  );
});
