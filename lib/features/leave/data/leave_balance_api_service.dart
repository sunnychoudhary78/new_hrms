import '../../../core/network/api_service.dart';

class LeaveBalanceApiService {
  final ApiService api;

  LeaveBalanceApiService(this.api);

  Future<List<dynamic>> fetchLeaveBalance() async {
    const pageSize = 100;
    final rows = <dynamic>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await api.get(
        '/employees/leave-balance',
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
        break;
      }

      page++;
    } while (page <= totalPages);

    return rows;
  }
}
