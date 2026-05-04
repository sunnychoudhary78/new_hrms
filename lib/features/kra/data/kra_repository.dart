import 'models/kra_model.dart';
import 'kra_api_service.dart';

class KraRepository {
  final KraApiService api;

  KraRepository(this.api);

  Future<List<KraModel>> listKras({
    String? departmentId,
    String? employeeId,
  }) async {
    return _mapAllPages(
      key: 'kras',
      fromJson: KraModel.fromJson,
      fetchPage: (page, limit) => api.listKras(
        departmentId: departmentId,
        employeeId: employeeId,
        page: page,
        limit: limit,
      ),
    );
  }

  Future<List<KraPerson>> getTeamMembers() async {
    return _mapAllPages(
      key: 'members',
      fromJson: KraPerson.fromJson,
      fetchPage: (page, limit) => api.getTeamMembers(
        page: page,
        limit: limit,
      ),
    );
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
    return _mapAllPages(
      key: 'cycles',
      fromJson: KraCycle.fromJson,
      fetchPage: (page, limit) => api.listCycles(
        page: page,
        limit: limit,
      ),
    );
  }

  Future<List<KraEvaluation>> listEvaluations({
    required String mode,
    String? cycleId,
  }) async {
    return _mapAllPages(
      key: 'evaluations',
      fromJson: KraEvaluation.fromJson,
      fetchPage: (page, limit) => api.listEvaluations(
        mode: mode,
        cycleId: cycleId,
        page: page,
        limit: limit,
      ),
    );
  }

  Future<void> submitRating({
    required String evaluationId,
    required List<Map<String, dynamic>> ratings,
    Map<String, String> documentPathsByKpi = const {},
  }) async {
    if (ratings.isEmpty) {
      throw Exception(
        'No KPI ratings in request. Your evaluation may still be loading — pull to refresh.',
      );
    }
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
    dynamic raw;
    if (response is List) {
      raw = response;
    } else if (response is Map) {
      raw = response[key];
      final data = response['data'];
      if (raw == null && data is Map) raw = data[key];
      if (raw == null && data is List) raw = data;
    }
    final list = raw is List ? raw : const [];
    return list
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<T>> _mapAllPages<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<dynamic> Function(int page, int limit) fetchPage,
  }) async {
    const pageSize = 100;
    final results = <T>[];
    var page = 1;
    var totalPages = 1;

    do {
      final res = await fetchPage(page, pageSize);
      results.addAll(_mapList(res, key, fromJson));

      final meta = res is Map ? res['meta'] : null;
      if (meta is Map && meta['totalPages'] != null) {
        totalPages = int.tryParse(meta['totalPages'].toString()) ?? totalPages;
      } else {
        break;
      }

      page++;
    } while (page <= totalPages);

    return results;
  }
}
