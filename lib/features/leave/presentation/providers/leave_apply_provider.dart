import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import '../../../../core/providers/network_providers.dart';
import '../../data/leave_apply_api_service.dart';

final leaveApplyApiProvider = Provider<LeaveApplyApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LeaveApplyApiService(api);
});

enum LeaveApplyStatus { idle, loading, success, error }

final leaveApplyProvider =
    NotifierProvider<LeaveApplyNotifier, LeaveApplyStatus>(
      LeaveApplyNotifier.new,
    );

class LeaveApplyNotifier extends Notifier<LeaveApplyStatus> {
  String? errorMessage;

  @override
  LeaveApplyStatus build() {
    return LeaveApplyStatus.idle;
  }

  Future<void> submitLeave({
    required Map<String, dynamic> data,
    File? document,
  }) async {
    if (state == LeaveApplyStatus.loading) return;

    final api = ref.read(leaveApplyApiProvider);
    final overlay = ref.read(globalLoadingProvider.notifier);

    state = LeaveApplyStatus.loading;

    overlay.showLoading("Submitting leave request...");

    try {
      await api.sendLeaveRequestWithDocument(data: data, document: document);

      state = LeaveApplyStatus.success;

      overlay.showSuccess("Leave applied successfully 🎉");

      state = LeaveApplyStatus.idle;
    } catch (e) {
      errorMessage = e.toString();

      state = LeaveApplyStatus.error;

      overlay.showError(errorMessage ?? "Failed to apply leave");

      state = LeaveApplyStatus.idle;
    }
  }
}
