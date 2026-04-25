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

  /// Manager
  Future<dynamic> getManagerPending() {
    return api.get(ApiEndpoints.managerPendingResignation);
  }

  /// HOD
  Future<dynamic> getHodPending() {
    return api.get(ApiEndpoints.hodPendingResignation);
  }

  /// HR
  Future<dynamic> getHrAll() {
    return api.get(ApiEndpoints.hrAllResignation);
  }

  Future<dynamic> approve(String id, String remarks) {
    return api.put("/resignations/$id/approve", {"remarks": remarks});
  }

  /// Reject
  Future<dynamic> reject(String id, String remarks) {
    return api.put("/resignations/$id/reject", {"remarks": remarks});
  }
}
