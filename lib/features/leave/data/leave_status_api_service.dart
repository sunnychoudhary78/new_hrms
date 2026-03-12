import '../../../../core/network/api_service.dart';

class LeaveStatusApiService {
  final ApiService api;

  LeaveStatusApiService(this.api);

  Future<List<dynamic>> fetchLeaveStatus() async {
    final response = await api.get('leave-requests/user/all');

    // API returns { data: [...], meta: {...} }

    if (response is Map && response['data'] is List) {
      return response['data'];
    }

    throw Exception("Unexpected leave status response");
  }

  Future<void> revokeLeave({required String requestId}) async {
    await api.patch('leave-requests/$requestId/withdraw', {
      "reason": "Leave withdrawn by user",
    });
  }
}
