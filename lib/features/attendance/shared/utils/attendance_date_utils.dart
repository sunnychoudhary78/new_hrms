import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';

/// Local calendar date as yyyy-MM-dd (matches web toLocaleDateString('en-CA')).
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String localTodayIso() => isoDate(DateTime.now());

String monthRangeFrom(int year, int month) => isoDate(DateTime(year, month, 1));

String monthRangeTo(int year, int month) =>
    isoDate(DateTime(year, month + 1, 0));

/// Normalize session.date to yyyy-MM-dd for comparison.
String sessionDateIso(AttendanceSession session) {
  final d = session.date;
  if (d.length >= 10) return d.substring(0, 10);
  return d;
}

/// Web-equivalent punch session filter:
/// - open sessions from any date
/// - closed sessions for today (by session.date)
List<AttendanceSession> filterPunchSessions(List<AttendanceSession> sessions) {
  final today = localTodayIso();
  return sessions.where((s) {
    if (s.checkOutTime == null) return true;
    return sessionDateIso(s) == today;
  }).toList();
}

AttendanceSession? findOpenSession(List<AttendanceSession> sessions) {
  try {
    return sessions.firstWhere((s) => s.checkOutTime == null);
  } catch (_) {
    return null;
  }
}

bool hasOpenSession(List<AttendanceSession> sessions) =>
    sessions.any((s) => s.checkOutTime == null);

List<AttendanceSession> todaySessions(List<AttendanceSession> sessions) {
  final today = localTodayIso();
  return sessions.where((s) => sessionDateIso(s) == today).toList();
}

bool canStartNewSession(List<AttendanceSession> sessions) =>
    !hasOpenSession(sessions) && todaySessions(sessions).length < 2;

bool isStaleOpenSession(List<AttendanceSession> sessions) {
  final open = findOpenSession(sessions);
  if (open == null) return false;
  return sessionDateIso(open) != localTodayIso();
}
