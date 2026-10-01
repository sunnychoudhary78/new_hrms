import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/shared/data/attendance_rerpository.dart';
import 'package:lms/features/auth/data/auth_api_service.dart';
import 'package:lms/features/attendance/mark_attendance/data/company_settings_repository.dart';
import 'package:lms/features/attendance/shared/utils/overtime_estimate_utils.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';

class HomeDashboardRepository {
  final AttendanceRepository attendanceRepo;
  final AuthApiService authApi;
  final CompanySettingsRepository companySettingsRepo;

  HomeDashboardRepository({
    required this.attendanceRepo,
    required this.authApi,
    required this.companySettingsRepo,
  });

  // ─────────────────────────────────────────────
  // LOAD HOME DASHBOARD DATA
  // ─────────────────────────────────────────────
  Future<HomeDashboardModel> loadDashboard({DateTime? month}) async {
    final profile = await _loadProfile();
    final todayStatus = await _loadTodayAttendance();
    final target = month ?? DateTime.now();
    final attendanceMonth = DateTime(target.year, target.month);

    final attendance = await _loadMonthAttendance(attendanceMonth);

    return HomeDashboardModel(
      userName: profile.userName,
      designation: profile.designation,
      profileImageUrl: profile.profileImageUrl,
      attendance: attendance.overview,
      stats: attendance.stats,
      distribution: attendance.distribution,
      todayStatus: todayStatus,
      lastFiveDays: attendance.bars,
      attendanceMonth: attendanceMonth,
    );
  }

  /// Reloads only the month charts. Profile and today's punch stay as they are.
  Future<HomeDashboardModel> loadAttendanceMonth(
    HomeDashboardModel current,
    DateTime month,
  ) async {
    final attendanceMonth = DateTime(month.year, month.month);
    final attendance = await _loadMonthAttendance(attendanceMonth);
    return current.copyWith(
      attendance: attendance.overview,
      stats: attendance.stats,
      distribution: attendance.distribution,
      lastFiveDays: attendance.bars,
      attendanceMonth: attendanceMonth,
    );
  }

  Future<({String userName, String designation, String? profileImageUrl})>
  _loadProfile() async {
    // 1️⃣ PROFILE
    final profileJson = await authApi.fetchProfile();

    print("📦 RAW PROFILE JSON:");
    print(profileJson);

    final String userName =
        profileJson['associates_name']?.toString() ??
        profileJson['name']?.toString() ??
        'User';

    String designation = 'Employee';

    final designationRaw = profileJson['designation'];

    if (designationRaw is Map) {
      designation = designationRaw['name']?.toString() ?? designation;
    } else if (designationRaw != null) {
      designation = designationRaw.toString();
    } else if (profileJson['role'] is Map) {
      designation = profileJson['role']['name']?.toString() ?? designation;
    }

    String? profileImageUrl;

    final profilePictureRaw = profileJson['profile_picture'];

    if (profilePictureRaw != null && profilePictureRaw.toString().isNotEmpty) {
      profileImageUrl =
          ApiConstants.imageBaseUrl + profilePictureRaw.toString();
    }

    print("👤 FINAL PROFILE:");
    print("Name: $userName");
    print("DesignationFinal: $designation");
    print("ProfileImageUrl: $profileImageUrl");

    return (
      userName: userName,
      designation: designation,
      profileImageUrl: profileImageUrl,
    );
  }

  Future<
    ({
      AttendanceOverview overview,
      AttendanceDistribution distribution,
      HomeStats stats,
      List<WeeklyAttendanceBar> bars,
    })
  >
  _loadMonthAttendance(DateTime month) async {
    final res = await attendanceRepo.fetchAttendance(
      month: month.month,
      year: month.year,
    );

    final monthSessions = await attendanceRepo.fetchMonthSessions(
      month: month.month,
      year: month.year,
    );

    final AttendanceSummary summary = res.summary;

    final overview = AttendanceOverview(
      workedMinutes: summary.totalMinutes,
      expectedMinutes: summary.expectedWorkingHours * 60,
    );

    // Same buckets as the web attendance summary (API values, not a local recount).
    final distribution = AttendanceDistribution(
      worked: summary.workingDays.toDouble(),
      leave: summary.totalLeaves.toDouble(),
      absent: summary.absentDays.toDouble(),
      late: summary.lateDays.toDouble(),
      weekOff: summary.totalWeekoffs.toDouble(),
      holiday: summary.totalHolidays.toDouble(),
    );

    final stats = HomeStats(
      payableDays: summary.payableDays.toDouble(),
      lateDays: summary.lateDays,
      absentDays: summary.absentDays.round(),
      totalLeaves: summary.totalLeaves,
    );

    final companySettings = await companySettingsRepo.fetchCompanySettings();
    final expectedMinutesPerDay = expectedMinutesFromOfficeHours(
      companySettings.officeStart,
      companySettings.officeEnd,
    );
    final effectiveExpectedPerDay = expectedMinutesPerDay > 0
        ? expectedMinutesPerDay
        : (summary.expectedWorkingHours <= 0
              ? 0
              : (summary.expectedWorkingHours * 60 /
                        _workingDayCount(month, res.days))
                    .round());

    final bars = _loadLastFiveDaysBars(
      month,
      effectiveExpectedPerDay,
      companySettings.autoCloseBufferMinutes,
      monthSessions,
      res.days,
    );

    return (
      overview: overview,
      distribution: distribution,
      stats: stats,
      bars: bars,
    );
  }

  /// Days in [month] that the backend treats as working days, for the
  /// per-day expected baseline when office hours are missing.
  int _workingDayCount(DateTime month, List<AttendanceAggregate> days) {
    final count = days.where((d) {
      final status = d.status.toLowerCase();
      return !status.contains('week') && !status.contains('holiday');
    }).length;
    if (count > 0) return count;
    return _allWorkingDaysOfMonth(month).length;
  }

  // ─────────────────────────────────────────────
  // TODAY CHECK-IN / CHECK-OUT
  // ─────────────────────────────────────────────
  Future<TodayAttendanceStatus> _loadTodayAttendance() async {
    final sessions = await attendanceRepo.fetchPunchSessions();

    print('🕘 Punch sessions count = ${sessions.length}');

    final open = findOpenSession(sessions);
    if (open != null) {
      return TodayAttendanceStatus(
        isCheckedIn: true,
        checkInTime: open.checkInTime,
        checkOutTime: open.checkOutTime,
      );
    }

    final today = localTodayIso();
    final todayClosed = sessions
        .where((s) => sessionDateIso(s) == today && s.checkOutTime != null)
        .toList();

    if (todayClosed.isEmpty) {
      return const TodayAttendanceStatus(isCheckedIn: false);
    }

    todayClosed.sort(
      (a, b) => a.checkInTime.compareTo(b.checkInTime),
    );
    final latest = todayClosed.last;

    return TodayAttendanceStatus(
      isCheckedIn: false,
      checkInTime: latest.checkInTime,
      checkOutTime: latest.checkOutTime,
    );
  }

  // ─────────────────────────────────────────────
  // ALL WORKING DAYS OF CURRENT MONTH (SKIP SUNDAY)
  // ─────────────────────────────────────────────
  List<DateTime> _allWorkingDaysOfMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final days = <DateTime>[];
    var cursor = firstDay;

    while (!cursor.isAfter(lastDay)) {
      if (cursor.weekday != DateTime.sunday) {
        days.add(DateTime(cursor.year, cursor.month, cursor.day));
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return days;
  }

  List<WeeklyAttendanceBar> _loadLastFiveDaysBars(
    DateTime month,
    int expectedMinsPerDay,
    int autoCloseBufferMinutes,
    List<AttendanceSession> sessions,
    List<AttendanceAggregate> summaryDays,
  ) {
    final statusByDate = <String, String>{};
    final workedByDate = <String, int>{};
    for (final day in summaryDays) {
      final key = dateKeyFromDateTime(day.date);
      statusByDate[key] = day.status;
      if (day.fullWorked > 0) {
        workedByDate[key] = day.fullWorked;
      }
    }

    final sessionsByDate = groupSessionsByDate(sessions);
    final workingDays = _allWorkingDaysOfMonth(month);

    return workingDays.map((day) {
      final key = dateKeyFromDateTime(day);
      final dayStatus = statusByDate[key] ?? '';
      final daySessions = sessionsByDate[key] ?? [];

      final expectedForDate = expectedMinutesForDate(
        dayStatus: dayStatus.isEmpty ? 'present' : dayStatus,
        expectedMinsPerDay: expectedMinsPerDay,
      );

      final result = computeDayWorked(
        daySessions: daySessions,
        expectedMinsPerDay: expectedMinsPerDay,
        expectedForDate: expectedForDate,
        autoCloseBufferMinutes: autoCloseBufferMinutes,
      );

      // Prefer backend worked minutes (fullWorked / totalMinutes) when present.
      final backendWorked = workedByDate[key];
      final workedMinutes = backendWorked ?? result.workedMinutes;

      return WeeklyAttendanceBar(
        date: day,
        workedMinutes: workedMinutes,
        expectedMinutes: result.expectedMinutes,
        estimatedOtMinutes: (workedMinutes - result.expectedMinutes).clamp(
          0,
          workedMinutes,
        ),
        isCapped: result.isAutoCloseCapped,
      );
    }).toList();
  }
}
