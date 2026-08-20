import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';

class AttendanceResponse {
  final List<AttendanceSession> sessions;
  final List<AttendanceAggregate> aggregates;

  AttendanceResponse({required this.sessions, required this.aggregates});

  AttendanceAggregate? get todayAggregate {
    final today = localTodayIso();
    for (final a in aggregates) {
      if (a.dateKey == today) return a;
    }
    return null;
  }

  String get todayStatus => todayAggregate?.status ?? '-';

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      sessions: (json['sessions'] as List? ?? [])
          .map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      aggregates: (json['aggregates'] as List? ?? [])
          .map((e) => AttendanceAggregate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
