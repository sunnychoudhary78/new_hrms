import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/network/api_service.dart';
import 'package:lms/features/policy/data/models/policy_model.dart';

class PolicyApiService {
  final ApiService api;

  PolicyApiService(this.api);

  Future<List<PolicyModel>> getPolicies() async {
    final response = await api.get(ApiEndpoints.policies);
    final rows = response is Map ? response['rows'] : response;

    if (rows is! List) return const [];

    return rows
        .whereType<Map>()
        .map((row) => PolicyModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
