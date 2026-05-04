import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/network/api_service.dart';

class ResignationApiService {
  final ApiService api;

  ResignationApiService(this.api);

  /// Submit
  Future<dynamic> submit(Map<String, dynamic> body) {
    return api.post(ApiEndpoints.resignation, body);
  }

  /// My resignation
  Future<dynamic> getMy() {
    return api.get(ApiEndpoints.myResignation);
  }

  /// Withdraw
  Future<dynamic> withdraw(String id) {
    return api.delete("${ApiEndpoints.resignation}/$id/withdraw", {});
  }

  /// Manager list (`GET resignations/manager/all`) — see API docs: `rows`, `meta`, optional `status`.
  Future<dynamic> getManagerResignations({
    required String status,
    int page = 1,
    int limit = 200,
  }) {
    return api.get(
      ApiEndpoints.managerAllResignation,
      queryParams: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );
  }

  /// HOD list (`GET resignations/hod/all`).
  Future<dynamic> getHodResignations({
    required String status,
    int page = 1,
    int limit = 200,
  }) {
    return api.get(
      ApiEndpoints.hodAllResignation,
      queryParams: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );
  }

  /// HR list (`GET resignations/hr/all`).
  Future<dynamic> getHrAll({
    required String status,
    int page = 1,
    int limit = 200,
  }) {
    return api.get(
      ApiEndpoints.hrAllResignation,
      queryParams: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );
  }

  Future<dynamic> approve(String id, String remarks) {
    return api.put("/resignations/$id/approve", {"remarks": remarks});
  }

  /// Reject
  Future<dynamic> reject(String id, String remarks) {
    return api.put("/resignations/$id/reject", {"remarks": remarks});
  }
}
