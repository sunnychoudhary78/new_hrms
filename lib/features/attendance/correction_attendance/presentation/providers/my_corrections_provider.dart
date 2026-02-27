import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/correction_attendance/data/models/attendance_request_model.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';

/// State class
class MyCorrectionsState {
  final bool isLoading;
  final String statusFilter;
  final List<AttendanceRequest> requests;

  /// For notification redirect auto-expand
  final String? expandRequestId;

  const MyCorrectionsState({
    required this.isLoading,
    required this.statusFilter,
    required this.requests,
    this.expandRequestId,
  });

  factory MyCorrectionsState.initial() {
    return const MyCorrectionsState(
      isLoading: false,
      statusFilter: 'ALL',
      requests: [],
      expandRequestId: null,
    );
  }

  MyCorrectionsState copyWith({
    bool? isLoading,
    String? statusFilter,
    List<AttendanceRequest>? requests,
    String? expandRequestId,
  }) {
    return MyCorrectionsState(
      isLoading: isLoading ?? this.isLoading,
      statusFilter: statusFilter ?? this.statusFilter,
      requests: requests ?? this.requests,
      expandRequestId: expandRequestId,
    );
  }
}

/// Provider
final myCorrectionsProvider =
    AsyncNotifierProvider<MyCorrectionsNotifier, MyCorrectionsState>(
      MyCorrectionsNotifier.new,
    );

class MyCorrectionsNotifier extends AsyncNotifier<MyCorrectionsState> {
  @override
  Future<MyCorrectionsState> build() async {
    debugPrint("🧱 MyCorrectionsNotifier build()");

    final initial = MyCorrectionsState.initial();

    state = AsyncData(initial);

    await fetchCorrections();

    return state.value!;
  }

  Future<void> fetchCorrections() async {
    final repo = ref.read(attendanceRepositoryProvider);

    final current = state.value!;

    state = AsyncData(current.copyWith(isLoading: true));

    try {
      final status = current.statusFilter == 'ALL'
          ? 'PENDING,APPROVED,REJECTED'
          : current.statusFilter;

      final list = await repo.fetchMyAttendanceCorrections(status: status);

      debugPrint("✅ Employee corrections fetched: ${list.length}");

      /// 🔥 IMPORTANT: read latest state again
      final latest = state.value!;

      state = AsyncData(
        latest.copyWith(
          isLoading: false,
          requests: list,
          // 👇 DO NOT TOUCH expandRequestId
        ),
      );
    } catch (e, st) {
      debugPrint("❌ Failed to fetch employee corrections → $e");
      debugPrintStack(stackTrace: st);

      final latest = state.value!;

      state = AsyncData(latest.copyWith(isLoading: false));
    }
  }

  /// Change filter
  Future<void> changeStatus(String status) async {
    final current = state.value!;

    state = AsyncData(current.copyWith(statusFilter: status));

    await fetchCorrections();
  }

  /// Used when opening from notification
  void expandRequest(String requestId) {
    final current = state.value!;

    state = AsyncData(current.copyWith(expandRequestId: requestId));
  }

  /// Clear expand state
  void clearExpand() {
    final current = state.value!;

    state = AsyncData(current.copyWith(expandRequestId: null));
  }
}
