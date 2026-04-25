import 'dart:io';
import 'package:lms/features/attendance/correction_attendance/data/models/attendance_request_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/shared/data/attendence_api_service.dart';
import 'package:lms/features/attendance/shared/data/models/mobile_config_model.dart';
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
  // TODAY ATTENDANCE (KEEPING OLD FOR NOW)
  // ─────────────────────────────────────────────

  Future<List<AttendanceSession>> fetchAttendanceToday() async {
    final now = DateTime.now();

    final res = await api.fetchAttendance(month: now.month, year: now.year);

    final sessions = (res['sessions'] as List? ?? [])
        .map((e) => AttendanceSession.fromJson(e))
        .toList();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return sessions.where((s) => isSameDay(s.checkInTime, now)).toList();
  }

  Future<List<AttendanceSession>> fetchMonthSessions({
    required int month,
    required int year,
  }) async {
    final res = await api.fetchAttendance(month: month, year: year);

    return (res['sessions'] as List? ?? [])
        .map((e) => AttendanceSession.fromJson(e))
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
