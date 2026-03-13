import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/leave/data/leave_type_api_service.dart';

import '../../../../core/providers/network_providers.dart';
import '../../data/leave_balance_api_service.dart';
import '../../data/models/leave_balance_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final leaveBalanceApiProvider = Provider<LeaveBalanceApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LeaveBalanceApiService(api);
});

final leaveTypeApiProvider = Provider<LeaveTypeApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LeaveTypeApiService(api);
});

final leaveBalanceProvider =
    AsyncNotifierProvider.autoDispose<LeaveBalanceNotifier, List<LeaveBalance>>(
      LeaveBalanceNotifier.new,
    );

class LeaveBalanceNotifier extends AsyncNotifier<List<LeaveBalance>> {
  @override
  Future<List<LeaveBalance>> build() async {
    final auth = ref.watch(authProvider);

    if (auth.isSubscriptionExpired) {
      throw Exception("SUBSCRIPTION_EXPIRED");
    }

    if (auth.profile == null) {
      throw Exception("USER_NOT_READY");
    }

    final balanceApi = ref.read(leaveBalanceApiProvider);
    final typeApi = ref.read(leaveTypeApiProvider);

    final balances = await balanceApi.fetchLeaveBalance();
    final types = await typeApi.fetchLeaveTypes();

    final Map<String, dynamic> typeMap = {for (var t in types) t['id']: t};

    return balances.map<LeaveBalance>((balance) {
      final leaveType = typeMap[balance['leave_type_id']];
      return LeaveBalance.fromJson(balance, leaveType);
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}
