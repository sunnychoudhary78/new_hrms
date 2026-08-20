import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/effective_shift_model.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';

final effectiveShiftProvider =
    AsyncNotifierProvider<EffectiveShiftNotifier, EffectiveShift>(
      EffectiveShiftNotifier.new,
    );

class EffectiveShiftNotifier extends AsyncNotifier<EffectiveShift> {
  @override
  Future<EffectiveShift> build() async {
    final repo = ref.read(attendanceRepositoryProvider);
    return repo.fetchEffectiveShift();
  }

  Future<void> refresh() async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      state = AsyncData(await repo.fetchEffectiveShift());
    } catch (_) {
      // keep last known shift on transient errors
    }
  }
}
