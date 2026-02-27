import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:lms/features/attendance/correction_attendance/data/models/attendance_request_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/shared/data/attendence_api_service.dart';
import 'package:lms/features/attendance/shared/data/models/attendance_response_model.dart';
import 'package:lms/features/attendance/shared/data/models/mobile_config_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';

class AttendanceRepository {
  final AttendanceApiService api;

  AttendanceRepository(this.api);

  // ─────────────────────────────────────────────
  // MOBILE CONFIG (NEW)
  // ─────────────────────────────────────────────

  Future<MobileConfig> fetchMobileConfig() async {
    final res = await api.fetchMobileConfig();
    return MobileConfig.fromJson(res);
  }

  // ─────────────────────────────────────────────
  // FETCH ATTENDANCE
  // ─────────────────────────────────────────────

  Future<AttendanceResponse> fetchAttendance({
    required int month,
    required int year,
  }) async {
    final res = await api.fetchAttendance(month: month, year: year);
    return AttendanceResponse.fromJson(res);
  }

  Future<AttendanceSummary> fetchSummary(String ym) async {
    final res = await api.fetchSummary(ym);
    return AttendanceSummary.fromJson(res);
  }

  Future<List<AttendanceSession>> fetchAttendanceToday() async {
    final now = DateTime.now();

    final res = await api.fetchAttendance(month: now.month, year: now.year);

    final attendance = AttendanceResponse.fromJson(res);

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return attendance.sessions
        .where((s) => isSameDay(s.checkInTime, now))
        .toList();
  }

  // ─────────────────────────────────────────────
  // CHECK-IN (JSON fallback)
  // ─────────────────────────────────────────────

  Future<void> punchIn(Map<String, dynamic> body) => api.punchIn(body);

  // ─────────────────────────────────────────────
  // MULTIPART CHECK-IN (UPDATED: file nullable)
  // ─────────────────────────────────────────────

  Future<void> punchInMultipart({
    File? file,
    required Map<String, dynamic> body,
  }) => api.punchInMultipart(file: file, body: body);

  // ─────────────────────────────────────────────
  // MULTIPART CHECK-OUT (UPDATED: file nullable)
  // ─────────────────────────────────────────────

  Future<void> punchOutMultipart({
    File? file,
    required Map<String, dynamic> body,
  }) => api.punchOutMultipart(file: file, body: body);

  // ─────────────────────────────────────────────
  // CHECK OUT (JSON fallback)
  // ─────────────────────────────────────────────

  Future<void> punchOut(Map<String, dynamic> body) => api.punchOut(body);

  // ─────────────────────────────────────────────
  // CORRECTIONS
  // ─────────────────────────────────────────────
  Future<void> requestCorrection(Map<String, dynamic> body) async {
    debugPrint("📤 REPOSITORY REQUEST CORRECTION");
    debugPrint("📦 BODY: $body");

    await api.requestCorrection(body);

    debugPrint("✅ REPOSITORY CORRECTION DONE");
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
