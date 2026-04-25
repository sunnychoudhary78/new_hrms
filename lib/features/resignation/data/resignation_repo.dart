import 'package:lms/features/resignation/data/models/resignation_model.dart';
import 'resignation_api_service.dart';

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

  /// ───────── MANAGER PENDING ─────────
  Future<List<ResignationModel>> getManagerPending() async {
    final res = await api.getManagerPending();

    final data = res['data'] as List;

    return data.map((e) => ResignationModel.fromJson(e)).toList();
  }

  /// ───────── HOD PENDING ─────────
  Future<List<ResignationModel>> getHodPending() async {
    final res = await api.getHodPending();

    final data = res['data'] as List;

    return data.map((e) => ResignationModel.fromJson(e)).toList();
  }

  /// ───────── HR ALL ─────────
  Future<List<ResignationModel>> getHrAll() async {
    final res = await api.getHrAll();

    final data = res['rows'] as List;

    return data.map((e) => ResignationModel.fromJson(e)).toList();
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
