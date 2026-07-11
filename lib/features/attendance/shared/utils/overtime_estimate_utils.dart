import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';

/// Parse HH:MM[:SS] to minutes since midnight (matches backend parseHM).
int parseOfficeTimeToMinutes(String? timeStr) {
  final parts = (timeStr ?? '00:00').split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return h * 60 + m;
}

/// Expected shift duration from office start/end (matches shiftService.getExpectedMinutesPerDay).
int expectedMinutesFromOfficeHours(String? officeStart, String? officeEnd) {
  final startM = parseOfficeTimeToMinutes(officeStart);
  final endM = parseOfficeTimeToMinutes(officeEnd);
  if (endM >= startM) return (endM - startM).clamp(0, 24 * 60);
  return (24 * 60 - startM + endM).clamp(0, 24 * 60);
}

bool isHolidayOrWeekOffStatus(String status) {
  final s = status.toLowerCase();
  return s.contains('week') || s.contains('holiday');
}

/// Cap session minutes when source is auto_close (matches autoCloseService.capMinutesForOt).
int capMinutesForOt(
  int sessionMins,
  int expectedMinsPerDay,
  int bufferMinutes,
  String source,
) {
  if (source != 'auto_close') {
    return sessionMins.clamp(0, sessionMins);
  }
  final cap = expectedMinsPerDay + bufferMinutes;
  return sessionMins.clamp(0, cap);
}

class DayWorkedResult {
  final int workedMinutes;
  final int expectedMinutes;
  final int estimatedOtMinutes;
  final bool isAutoCloseCapped;

  const DayWorkedResult({
    required this.workedMinutes,
    required this.expectedMinutes,
    required this.estimatedOtMinutes,
    this.isAutoCloseCapped = false,
  });
}

/// Expected minutes for OT baseline on a given day (0 on holiday/week-off).
int expectedMinutesForDate({
  required String dayStatus,
  required int expectedMinsPerDay,
}) {
  if (isHolidayOrWeekOffStatus(dayStatus)) return 0;
  return expectedMinsPerDay;
}

/// Sum capped session minutes and derive estimated OT for one calendar day.
DayWorkedResult computeDayWorked({
  required List<AttendanceSession> daySessions,
  required int expectedMinsPerDay,
  required int expectedForDate,
  required int autoCloseBufferMinutes,
}) {
  var worked = 0;
  var isCapped = false;

  for (final session in daySessions) {
    var mins = session.durationMinutes;
    if (mins < 0) mins = 0;

    final capped = capMinutesForOt(
      mins,
      expectedMinsPerDay,
      autoCloseBufferMinutes,
      session.source,
    );
    if (capped < mins) isCapped = true;
    worked += capped;
  }

  final ot = (worked - expectedForDate).clamp(0, worked);

  return DayWorkedResult(
    workedMinutes: worked,
    expectedMinutes: expectedForDate,
    estimatedOtMinutes: ot,
    isAutoCloseCapped: isCapped,
  );
}

String dateKeyFromDateTime(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, List<AttendanceSession>> groupSessionsByDate(
  List<AttendanceSession> sessions,
) {
  final map = <String, List<AttendanceSession>>{};
  for (final s in sessions) {
    final key = s.date.length >= 10 ? s.date.substring(0, 10) : s.date;
    map.putIfAbsent(key, () => []).add(s);
  }
  return map;
}
