import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/leave/data/models/leave_approve_model.dart';

import '../../../../core/providers/network_providers.dart';
import '../../../../core/providers/global_loading_provider.dart';

import '../../data/leave_approve_api_service.dart';

final leaveApproveApiProvider = Provider<LeaveApproveApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LeaveApproveApiService(api);
});

final leaveApproveProvider =
    AsyncNotifierProvider.autoDispose<
      LeaveApproveNotifier,
      List<ManagerLeaveRequest>
    >(LeaveApproveNotifier.new);

class LeaveApproveNotifier extends AsyncNotifier<List<ManagerLeaveRequest>> {
  @override
  Future<List<ManagerLeaveRequest>> build() async {
    final api = ref.read(leaveApproveApiProvider);

    final list = await api.fetchManagerRequests();

    return list
        .map<ManagerLeaveRequest>((e) => ManagerLeaveRequest.fromJson(e))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  Future<void> approve(
    String id,
    String? comment,
    List<Map<String, dynamic>> dates,
  ) async {
    final api = ref.read(leaveApproveApiProvider);
    final loader = ref.read(globalLoadingProvider.notifier);

    try {
      loader.showLoading("Approving leave...");

      await api.approveLeave(id, comment, dates);

      await refresh();

      loader.showSuccess("Leave approved successfully");
    } catch (e) {
      loader.showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> reject(String id, String? comment) async {
    final api = ref.read(leaveApproveApiProvider);
    final loader = ref.read(globalLoadingProvider.notifier);

    try {
      loader.showLoading("Rejecting leave...");

      await api.rejectLeave(id, comment);

      await refresh();

      loader.showSuccess("Leave rejected successfully");
    } catch (e) {
      loader.showError(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
