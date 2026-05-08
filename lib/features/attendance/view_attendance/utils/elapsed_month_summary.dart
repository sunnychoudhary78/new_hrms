import 'package:intl/intl.dart';

import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';
import 'package:lms/features/dashboard/data/models/attendance_day_data.dart';

bool _isNonWorkingStatus(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  return status.contains('week off') ||
      status.contains('weekoff') ||
      status.contains('week-off') ||
      status.contains('holiday');
}

bool _isLeaveStatus(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  return status.contains('leave');
}

bool _isPresentLikeStatus(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  return status.contains('present') ||
      status.contains('on-time') ||
      status.contains('ontime') ||
      status.contains('late');
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Same rules as [HomeDashboardRepository] distribution: only month days that
/// are not in the future count toward buckets (future days are not "absent").
bool _effectivePresentLike(
  String dayStatus,
  DateTime dayDate,
  Set<String> datesWithCheckIn,
) {
  final key = _dateKey(dayDate);
  if (datesWithCheckIn.contains(key)) {
    if (_isNonWorkingStatus(dayStatus)) return false;
    if (_isLeaveStatus(dayStatus)) return false;
    return true;
  }
  return _isPresentLikeStatus(dayStatus);
}

Set<String> _datesWithCheckIn(Map<String, AttendanceDayData> attendanceMap) {
  final set = <String>{};
  for (final e in attendanceMap.entries) {
    if (e.value.sessions.any((s) => s.checkIn != null)) {
      set.add(e.key);
    }
  }
  return set;
}

/// Recomputes working / late / leave / absent for days from the start of the
/// month through today so stats match the home dashboard pie logic.
AttendanceSummary resolveElapsedMonthSummary({
  required AttendanceSummary apiSummary,
  required List<AttendanceAggregate> aggregates,
  required Map<String, AttendanceDayData> attendanceMap,
}) {
  if (aggregates.isEmpty) return apiSummary;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final datesWithCheckIn = _datesWithCheckIn(attendanceMap);

  var trackedWorkingDays = 0;
  var presentLikeDays = 0;
  var leaveDays = 0;

  for (final agg in aggregates) {
    final date = DateTime(agg.date.year, agg.date.month, agg.date.day);
    if (date.isAfter(today)) continue;
    if (date.weekday == DateTime.sunday) continue;

    final key = DateFormat('yyyy-MM-dd').format(agg.date);
    final resolved = attendanceMap[key];
    final status = resolved?.status ?? agg.status;

    if (_isNonWorkingStatus(status)) continue;
    trackedWorkingDays++;

    if (_isLeaveStatus(status)) {
      leaveDays++;
    } else if (_effectivePresentLike(status, date, datesWithCheckIn)) {
      presentLikeDays++;
    }
  }

  final lateDays = apiSummary.lateDays.clamp(0, presentLikeDays);
  final workedDays = (presentLikeDays - lateDays).clamp(0, presentLikeDays);
  final absentDays = (trackedWorkingDays - presentLikeDays - leaveDays).clamp(
    0,
    trackedWorkingDays,
  );

  return AttendanceSummary(
    workingDays: workedDays,
    lateDays: lateDays,
    totalLeaves: leaveDays,
    absentDays: absentDays,
    payableDays: apiSummary.payableDays,
    totalMinutes: apiSummary.totalMinutes,
    expectedWorkingHours: apiSummary.expectedWorkingHours,
  );
}
