import 'models/kra_model.dart';
import 'kra_api_service.dart';

class KraRepository {
  final KraApiService api;

  KraRepository(this.api);

  Future<List<KraModel>> listKras({
    String? departmentId,
    String? employeeId,
  }) async {
    final res = await api.listKras(
      departmentId: departmentId,
      employeeId: employeeId,
    );
    return _mapList(res, 'kras', KraModel.fromJson);
  }

  Future<List<KraPerson>> getTeamMembers() async {
    final res = await api.getTeamMembers();
    return _mapList(res, 'members', KraPerson.fromJson);
  }

  Future<KraModel> saveKra({
    String? id,
    required String name,
    required String description,
    String? departmentId,
    String? employeeId,
    required List<KpiModel> kpis,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      if (departmentId != null && departmentId.trim().isNotEmpty)
        'department_id': departmentId.trim(),
      if (employeeId != null && employeeId.trim().isNotEmpty)
        'employee_id': employeeId.trim(),
      'kpis': kpis.map((e) => e.toPayload()).toList(),
    };

    final res = id == null || id.isEmpty
        ? await api.createKra(payload)
        : await api.updateKra(id, payload);

    final raw = res is Map ? res['kra'] : null;
    if (raw is Map) {
      return KraModel.fromJson(Map<String, dynamic>.from(raw));
    }
    throw Exception('Invalid KRA response');
  }

  Future<void> deleteKra(String id) => api.deleteKra(id);

  Future<KraCycle> initiateCycle({
    required int month,
    required int year,
  }) async {
    final res = await api.initiateCycle(month: month, year: year);
    final raw = res is Map ? res['cycle'] : null;
    if (raw is Map) {
      return KraCycle.fromJson(Map<String, dynamic>.from(raw));
    }
    throw Exception('Invalid cycle response');
  }

  Future<KraCycle?> getActiveCycle() async {
    final res = await api.getActiveCycle();
    final raw = res is Map ? res['cycle'] : null;
    if (raw is Map) {
      return KraCycle.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<List<KraCycle>> listCycles() async {
    final res = await api.listCycles();
    return _mapList(res, 'cycles', KraCycle.fromJson);
  }

  Future<List<KraEvaluation>> listEvaluations({
    required String mode,
    String? cycleId,
  }) async {
    final res = await api.listEvaluations(mode: mode, cycleId: cycleId);
    return _mapList(res, 'evaluations', KraEvaluation.fromJson);
  }

  Future<void> submitRating({
    required String evaluationId,
    required List<Map<String, dynamic>> ratings,
    Map<String, String> documentPathsByKpi = const {},
  }) async {
    await api.submitRating(
      evaluationId: evaluationId,
      ratings: ratings,
      documentPathsByKpi: documentPathsByKpi,
    );
  }

  List<T> _mapList<T>(
    dynamic response,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = response is Map ? response[key] : null;
    final list = raw is List ? raw : const [];
    return list
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
