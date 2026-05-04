import '../../../../core/network/api_service.dart';

class LeaveStatusApiService {
  final ApiService api;

  LeaveStatusApiService(this.api);

  Future<List<dynamic>> fetchLeaveStatus() async {
    const pageSize = 100;
    final rows = <dynamic>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await api.get(
        'leave-requests/user/all',
        queryParams: {"page": page, "limit": pageSize},
      );

      if (response is List) {
        return response;
      }

      if (response is Map && response['data'] is List) {
        rows.addAll(response['data'] as List);
        final meta = response['meta'];
        if (meta is Map && meta['totalPages'] != null) {
          totalPages =
              int.tryParse(meta['totalPages'].toString()) ?? totalPages;
        } else {
          break;
        }
      } else {
        throw Exception("Unexpected leave status response");
      }

      page++;
    } while (page <= totalPages);

    return rows;
  }

  Future<void> revokeLeave({required String requestId}) async {
    await api.patch('leave-requests/$requestId/withdraw', {
      "reason": "Leave withdrawn by user",
    });
  }
}
