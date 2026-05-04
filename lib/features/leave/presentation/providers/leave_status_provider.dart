import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/leave/data/models/leave_status_model.dart';
import '../../../../core/providers/global_loading_provider.dart';
import '../../../../core/providers/network_providers.dart';
import '../../data/leave_status_api_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'leave_details_provider.dart';

final leaveStatusApiProvider = Provider<LeaveStatusApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LeaveStatusApiService(api);
});

final leaveStatusProvider =
    AsyncNotifierProvider.autoDispose<LeaveStatusNotifier, List<LeaveStatus>>(
      LeaveStatusNotifier.new,
    );

class LeaveStatusNotifier extends AsyncNotifier<List<LeaveStatus>> {
  @override
  Future<List<LeaveStatus>> build() async {
    ref.watch(authProvider);

    final api = ref.read(leaveStatusApiProvider);

    final list = await api.fetchLeaveStatus();

    return list.map<LeaveStatus>((e) => LeaveStatus.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    try {
      final data = await build();

      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> revokeLeave(String id) async {
    final api = ref.read(leaveStatusApiProvider);
    final overlay = ref.read(globalLoadingProvider.notifier);

    overlay.showLoading("Submitting revocation request...");

    try {
      await api.revokeLeave(requestId: id);

      ref.invalidate(leaveDetailsProvider(id));

      await refresh();

      overlay.showSuccess("Leave revocation requested");
    } catch (e) {
      overlay.showError(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
