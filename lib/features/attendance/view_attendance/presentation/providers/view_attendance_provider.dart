import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';
import 'package:lms/features/attendance/shared/data/attendance_rerpository.dart';

final viewAttendanceProvider =
    AsyncNotifierProvider<ViewAttendanceNotifier, ViewAttendanceState>(
      ViewAttendanceNotifier.new,
    );

class ViewAttendanceState {
  final List<AttendanceAggregate> aggregates;
  final AttendanceSummary? summary;
  final List<AttendanceSession> sessions;

  const ViewAttendanceState({
    required this.aggregates,
    required this.summary,
    required this.sessions,
  });
}

class ViewAttendanceNotifier extends AsyncNotifier<ViewAttendanceState> {
  late AttendanceRepository _repo;
  late DateTime _currentMonth;

  @override
  Future<ViewAttendanceState> build() async {
    /// 🔒 SUBSCRIPTION GUARD
    _repo = ref.read(attendanceRepositoryProvider);
    _currentMonth = DateTime.now();
    return _loadMonth(_currentMonth);
  }

  Future<ViewAttendanceState> _loadMonth(DateTime date) async {
    final res = await _repo.fetchAttendance(month: date.month, year: date.year);

    final summary = await _repo.fetchSummary(
      "${date.year}-${date.month.toString().padLeft(2, '0')}",
    );

    return ViewAttendanceState(
      aggregates: res.aggregates,
      sessions: res.sessions,
      summary: summary,
    );
  }

  Future<void> changeMonth(DateTime date) async {
    _currentMonth = date;

    final newState = await _loadMonth(date);

    state = AsyncData(newState);
  }

  Future<void> requestAttendanceCorrection({
    required DateTime date,
    required TimeOfDay checkIn,
    TimeOfDay? checkOut,
    required String reason,
  }) async {
    String toIso(DateTime d, TimeOfDay t) {
      return DateTime(
        d.year,
        d.month,
        d.day,
        t.hour,
        t.minute,
      ).toIso8601String();
    }

    final body = {
      "targetDate": date.toIso8601String().split('T').first,
      "proposedCheckIn": toIso(date, checkIn),
      if (checkOut != null) "proposedCheckOut": toIso(date, checkOut),
      "reason": reason,
    };

    await _repo.requestCorrection(body);

    state = const AsyncLoading();
    state = AsyncData(await _loadMonth(_currentMonth));
  }
}
