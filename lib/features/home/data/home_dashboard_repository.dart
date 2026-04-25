import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/shared/data/attendance_rerpository.dart';
import 'package:lms/features/auth/data/auth_api_service.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';

class HomeDashboardRepository {
  final AttendanceRepository attendanceRepo;
  final AuthApiService authApi;

  HomeDashboardRepository({
    required this.attendanceRepo,
    required this.authApi,
  });

  // ─────────────────────────────────────────────
  // LOAD HOME DASHBOARD DATA
  // ─────────────────────────────────────────────
  Future<HomeDashboardModel> loadDashboard() async {
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

    // 2️⃣ ATTENDANCE SUMMARY (MONTH)
    final now = DateTime.now();

    final res = await attendanceRepo.fetchAttendance(
      month: now.month,
      year: now.year,
    );

    final monthSessions = await attendanceRepo.fetchMonthSessions(
      month: now.month,
      year: now.year,
    );

    final datesWithCheckIn = _datesWithCheckIn(monthSessions);

    final AttendanceSummary summary = res.summary;

    print(
      '📦 Summary → workedMin=${summary.totalMinutes} '
      'expectedHrs=${summary.expectedWorkingHours}',
    );

    // 3️⃣ ATTENDANCE OVERVIEW
    final attendanceOverview = AttendanceOverview(
      workedMinutes: summary.totalMinutes,
      expectedMinutes: summary.expectedWorkingHours * 60,
    );

    // 4️⃣ QUICK STATS (absent aligned with pie once computed below)

    // 5️⃣ DISTRIBUTION (exclusive buckets for elapsed month days)
    final today = DateTime(now.year, now.month, now.day);
    int presentLikeDays = 0;
    int leaveDays = 0;
    int trackedWorkingDays = 0;

    for (final day in res.days) {
      final date = DateTime(day.date.year, day.date.month, day.date.day);
      if (date.isAfter(today)) continue;
      if (date.weekday == DateTime.sunday) continue;

      if (_isNonWorkingStatus(day.status)) continue;
      trackedWorkingDays++;

      if (_isLeaveStatus(day.status)) {
        leaveDays++;
      } else if (_effectivePresentLike(day.status, date, datesWithCheckIn)) {
        presentLikeDays++;
      }
    }

    // Late is a subset of present-like; keep pie slices mutually exclusive.
    final lateDays = summary.lateDays.clamp(0, presentLikeDays);
    final workedDays = (presentLikeDays - lateDays).clamp(0, presentLikeDays);
    final absentDays = (trackedWorkingDays - presentLikeDays - leaveDays).clamp(
      0,
      trackedWorkingDays,
    );

    final distribution = AttendanceDistribution(
      worked: workedDays.toDouble(),
      leave: leaveDays.toDouble(),
      absent: absentDays.toDouble(),
      late: lateDays.toDouble(),
    );

    final stats = HomeStats(
      payableDays: summary.payableDays.toDouble(),
      lateDays: summary.lateDays,
      absentDays: distribution.absent.round(),
      totalLeaves: summary.totalLeaves,
    );

    // 6️⃣ TODAY STATUS
    final todayStatus = await _loadTodayAttendance();

    // 7️⃣ MONTH WORKING DAYS BARS
    const int expectedMinutesPerDay = 540;

    print(
      '📊 Loading month working days bars (expected=$expectedMinutesPerDay min)',
    );

    final lastFiveDays = await _loadLastFiveDaysBars(
      expectedMinutesPerDay,
      monthSessions,
    );

    return HomeDashboardModel(
      userName: userName,
      designation: designation,
      profileImageUrl: profileImageUrl,
      attendance: attendanceOverview,
      stats: stats,
      distribution: distribution,
      todayStatus: todayStatus,
      lastFiveDays: lastFiveDays,
    );
  }

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

  String _calendarDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Set<String> _datesWithCheckIn(List<AttendanceSession> sessions) {
    final set = <String>{};
    for (final s in sessions) {
      final d = DateTime(
        s.checkInTime.year,
        s.checkInTime.month,
        s.checkInTime.day,
      );
      set.add(_calendarDateKey(d));
    }
    return set;
  }

  /// Counts as present when summary says so, or when session data proves check-in
  /// even if the summary row is still "absent" before checkout.
  bool _effectivePresentLike(
    String dayStatus,
    DateTime dayDate,
    Set<String> datesWithCheckIn,
  ) {
    final key = _calendarDateKey(dayDate);
    if (datesWithCheckIn.contains(key)) {
      if (_isNonWorkingStatus(dayStatus)) return false;
      if (_isLeaveStatus(dayStatus)) return false;
      return true;
    }
    return _isPresentLikeStatus(dayStatus);
  }

  // ─────────────────────────────────────────────
  // TODAY CHECK-IN / CHECK-OUT
  // ─────────────────────────────────────────────
  Future<TodayAttendanceStatus> _loadTodayAttendance() async {
    final sessions = await attendanceRepo.fetchAttendanceToday();

    print('🕘 Today sessions count = ${sessions.length}');

    if (sessions.isEmpty) {
      return const TodayAttendanceStatus(isCheckedIn: false);
    }

    final latest = sessions.last;

    return TodayAttendanceStatus(
      isCheckedIn: latest.checkOutTime == null,
      checkInTime: latest.checkInTime,
      checkOutTime: latest.checkOutTime,
    );
  }

  // ─────────────────────────────────────────────
  // ALL WORKING DAYS OF CURRENT MONTH (SKIP SUNDAY)
  // ─────────────────────────────────────────────
  List<DateTime> _allWorkingDaysOfMonth() {
    final now = DateTime.now();

    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final days = <DateTime>[];

    var cursor = firstDay;

    while (!cursor.isAfter(lastDay)) {
      if (cursor.weekday != DateTime.sunday) {
        days.add(DateTime(cursor.year, cursor.month, cursor.day));
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    print(
      '📅 All working days → '
      '${days.map((d) => d.toIso8601String().split("T").first).join(", ")}',
    );

    return days;
  }

  // ─────────────────────────────────────────────
  // BUILD BARS FOR MONTH WORKING DAYS
  // ─────────────────────────────────────────────
  Future<List<WeeklyAttendanceBar>> _loadLastFiveDaysBars(
    int expectedMinutesPerDay,
    List<AttendanceSession> sessions,
  ) async {
    const int maxAllowedMinutesPerDay = 650;

    print('📦 Sessions fetched = ${sessions.length}');
    final Map<DateTime, int> workedByDate = {};

    for (final session in sessions) {
      final day = DateTime.parse(session.date);

      final dayKey = DateTime(day.year, day.month, day.day);

      int minutes = 0;

      minutes = session.durationMinutes;

      workedByDate[dayKey] = (workedByDate[dayKey] ?? 0) + minutes;
    }

    final workingDays = _allWorkingDaysOfMonth();

    final bars = workingDays.map((day) {
      final worked = workedByDate[day] ?? 0;

      final cappedWorked = worked.clamp(0, maxAllowedMinutesPerDay);

      final isCapped = worked > maxAllowedMinutesPerDay;

      return WeeklyAttendanceBar(
        date: day,
        workedMinutes: cappedWorked,
        expectedMinutes: expectedMinutesPerDay,
        isCapped: isCapped,
      );
    }).toList();

    print(' Final bars count → ${bars.length}');

    return bars;
  }
}
