import 'package:lms/features/resignation/data/models/resignation_model.dart';
import 'resignation_api_service.dart';
import 'resignation_list_query.dart';

List<ResignationModel> _resignationListFromResponse(dynamic res) {
  if (res is! Map) return [];

  final map = Map<String, dynamic>.from(res);
  dynamic rawList;

  // Paginated list endpoints: `{ success, rows, meta }` — prefer `rows` so we
  // never take an empty `data` list when `rows` holds the real page (API docs).
  if (map['rows'] is List) {
    rawList = map['rows'];
  } else {
    final data = map['data'];
    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      rawList = data['rows'] ?? data['items'] ?? data['list'];
    }
    rawList ??= map['items'];
  }

  if (rawList is! List) return [];

  final out = <ResignationModel>[];
  for (final e in rawList) {
    if (e is Map<String, dynamic>) {
      out.add(ResignationModel.fromJson(e));
    } else if (e is Map) {
      out.add(ResignationModel.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}

/// Backend `status=All` often omits withdrawn rows; merge so the app matches the web “all” view.
List<ResignationModel> _mergeResignationListsById(
  List<ResignationModel> a,
  List<ResignationModel> b,
) {
  final byId = <String, ResignationModel>{};
  for (final r in [...a, ...b]) {
    final id = r.id;
    if (id.isEmpty) continue;
    byId.putIfAbsent(id, () => r);
  }
  return byId.values.toList();
}

Future<List<ResignationModel>> _fetchAllResignationPages(
  Future<dynamic> Function({
    required String status,
    int page,
    int limit,
  }) fetch, {
  required String status,
}) async {
  const pageSize = 200;
  final all = <ResignationModel>[];
  var page = 1;
  var totalPages = 1;

  do {
    final res = await fetch(status: status, page: page, limit: pageSize);
    all.addAll(_resignationListFromResponse(res));

    final meta = res is Map ? res['meta'] : null;
    final totalPagesRaw = meta is Map
        ? (meta['totalPages'] ?? meta['total_pages'])
        : null;
    if (totalPagesRaw != null) {
      totalPages = int.tryParse(totalPagesRaw.toString()) ?? totalPages;
    } else {
      break;
    }

    page++;
  } while (page <= totalPages);

  return all;
}

class ResignationRepository {
  final ResignationApiService api;

  ResignationRepository(this.api);

  /// ───────── GET MY RESIGNATION ─────────
  Future<ResignationModel?> getMy() async {
    final res = await api.getMy();

    final data = res['data'];

    if (data == null) return null;

    // ✅ HANDLE LIST PROPERLY
    if (data is List && data.isNotEmpty) {
      return ResignationModel.fromJson(data.first);
    }

    return null;
  }

  /// ───────── MANAGER DASHBOARD LIST ─────────
  Future<List<ResignationModel>> getManagerResignations({
    ResignationListQuery filter = ResignationListQuery.all,
  }) async {
    if (filter == ResignationListQuery.all) {
      final allRes = await _fetchAllResignationPages(
        api.getManagerResignations,
        status: ResignationListQuery.all.apiStatus,
      );
      final withdrawnRes = await _fetchAllResignationPages(
        api.getManagerResignations,
        status: ResignationListQuery.withdrawn.apiStatus,
      );
      return _mergeResignationListsById(
        allRes,
        withdrawnRes,
      );
    }
    return _fetchAllResignationPages(
      api.getManagerResignations,
      status: filter.apiStatus,
    );
  }

  /// ───────── HOD DASHBOARD LIST ─────────
  Future<List<ResignationModel>> getHodResignations({
    ResignationListQuery filter = ResignationListQuery.all,
  }) async {
    if (filter == ResignationListQuery.all) {
      final allRes = await _fetchAllResignationPages(
        api.getHodResignations,
        status: ResignationListQuery.all.apiStatus,
      );
      final withdrawnRes = await _fetchAllResignationPages(
        api.getHodResignations,
        status: ResignationListQuery.withdrawn.apiStatus,
      );
      return _mergeResignationListsById(
        allRes,
        withdrawnRes,
      );
    }
    return _fetchAllResignationPages(
      api.getHodResignations,
      status: filter.apiStatus,
    );
  }

  /// ───────── HR ALL ─────────
  Future<List<ResignationModel>> getHrAll({
    ResignationListQuery filter = ResignationListQuery.all,
  }) async {
    if (filter == ResignationListQuery.all) {
      final allRes = await _fetchAllResignationPages(
        api.getHrAll,
        status: ResignationListQuery.all.apiStatus,
      );
      final withdrawnRes = await _fetchAllResignationPages(
        api.getHrAll,
        status: ResignationListQuery.withdrawn.apiStatus,
      );
      return _mergeResignationListsById(
        allRes,
        withdrawnRes,
      );
    }
    return _fetchAllResignationPages(
      api.getHrAll,
      status: filter.apiStatus,
    );
  }

  /// ───────── SUBMIT ─────────
  Future<void> submit({
    required String reason,
    String? lastWorkingDate,
    int? noticePeriodDays,
  }) async {
    await api.submit({
      "reason": reason,
      "last_working_date": lastWorkingDate,
      "notice_period_days": noticePeriodDays,
    });
  }

  /// ───────── WITHDRAW ─────────
  Future<void> withdraw(String id) async {
    await api.withdraw(id);
  }

  /// ───────── APPROVE ─────────
  Future<void> approve(String id, String remarks) async {
    await api.approve(id, remarks);
  }

  /// ───────── REJECT ─────────
  Future<void> reject(String id, String remarks) async {
    await api.reject(id, remarks);
  }
}
