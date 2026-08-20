import 'dart:io';
import 'package:lms/features/attendance/correction_attendance/data/models/attendance_request_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/effective_shift_model.dart';
import 'package:lms/features/attendance/shared/data/attendence_api_service.dart';
import 'package:lms/features/attendance/shared/data/models/attendance_response_model.dart';
import 'package:lms/features/attendance/shared/data/models/mobile_config_model.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_full_response.dart';

class AttendanceRepository {
  final AttendanceApiService api;

  AttendanceRepository(this.api);

  // ─────────────────────────────────────────────
  // MOBILE CONFIG
  // ─────────────────────────────────────────────

  Future<MobileConfig> fetchMobileConfig() async {
    final res = await api.fetchMobileConfig();
    return MobileConfig.fromJson(res);
  }

  Future<EffectiveShift> fetchEffectiveShift({String? userId}) async {
    final res = await api.fetchEffectiveShift(userId: userId);
    return EffectiveShift.fromJson(res);
  }

  // ─────────────────────────────────────────────
  // ✅ NEW: FETCH ATTENDANCE (SUMMARY + DAYS)
  // ─────────────────────────────────────────────

  Future<AttendanceFullResponse> fetchAttendance({
    required int month,
    required int year,
  }) async {
    final monthStr = "$year-${month.toString().padLeft(2, '0')}";

    final res = await api.fetchSummary(monthStr);

    return AttendanceFullResponse.fromJson(res);
  }

  // ─────────────────────────────────────────────
  // PUNCH SESSIONS (aligned with web attendance page)
  // ─────────────────────────────────────────────

  /// Open sessions from any date + closed sessions for today (by session.date).
  Future<AttendanceResponse> fetchPunchAttendance() async {
    final today = DateTime.now();
    final from = today.subtract(const Duration(days: 7));

    final res = await api.fetchAttendance(
      from: isoDate(from),
      to: isoDate(today),
    );

    final parsed = AttendanceResponse.fromJson(res);

    return AttendanceResponse(
      sessions: filterPunchSessions(parsed.sessions),
      aggregates: parsed.aggregates,
    );
  }

  Future<List<AttendanceSession>> fetchPunchSessions() async {
    final res = await fetchPunchAttendance();
    return res.sessions;
  }

  /// @deprecated Use [fetchPunchSessions].
  Future<List<AttendanceSession>> fetchAttendanceToday() => fetchPunchSessions();

  Future<List<AttendanceSession>> fetchMonthSessions({
    required int month,
    required int year,
  }) async {
    final res = await api.fetchAttendance(
      from: monthRangeFrom(year, month),
      to: monthRangeTo(year, month),
    );

    return (res['sessions'] as List? ?? [])
        .map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────
  // CHECK-IN
  // ─────────────────────────────────────────────

  Future<void> punchIn(Map<String, dynamic> body) => api.punchIn(body);

  Future<void> punchInMultipart({
    File? file,
    required Map<String, dynamic> body,
  }) => api.punchInMultipart(file: file, body: body);

  // ─────────────────────────────────────────────
  // CHECK-OUT
  // ─────────────────────────────────────────────

  Future<void> punchOut(Map<String, dynamic> body) => api.punchOut(body);

  Future<void> punchOutMultipart({
    File? file,
    required Map<String, dynamic> body,
  }) => api.punchOutMultipart(file: file, body: body);

  // ─────────────────────────────────────────────
  // CORRECTIONS
  // ─────────────────────────────────────────────

  Future<void> requestCorrection(Map<String, dynamic> body) async {
    await api.requestCorrection(body);
  }

  Future<List<AttendanceRequest>> fetchAttendanceCorrections({
    required String status,
  }) async {
    final list = await api.fetchAttendanceCorrectionsManaged(status: status);

    return list.map((e) => AttendanceRequest.fromJson(e)).toList();
  }

  Future<List<AttendanceRequest>> fetchMyAttendanceCorrections({
    required String status,
  }) async {
    final list = await api.fetchAttendanceCorrectionsMy(status: status);

    return list.map((e) => AttendanceRequest.fromJson(e)).toList();
  }

  Future<void> updateCorrectionStatus({
    required String id,
    required String status,
    String? note,
  }) => api.updateCorrectionStatus(
    id: id,
    body: {"action": status, if (note != null) "note": note},
  );
}
