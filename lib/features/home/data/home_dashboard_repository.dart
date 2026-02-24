import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/home/data/models/home_dashboard_model.dart';
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
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final AttendanceSummary summary = await attendanceRepo.fetchSummary(
      monthKey,
    );

    print(
      '📦 Summary → workedMin=${summary.totalMinutes} '
      'expectedHrs=${summary.expectedWorkingHours}',
    );

    // 3️⃣ ATTENDANCE OVERVIEW
    final attendanceOverview = AttendanceOverview(
      workedMinutes: summary.totalMinutes,
      expectedMinutes: summary.expectedWorkingHours * 60,
    );

    // 4️⃣ QUICK STATS
    final stats = HomeStats(
      payableDays: summary.payableDays.toDouble(),
      lateDays: summary.lateDays,
      absentDays: summary.absentDays,
      totalLeaves: summary.totalLeaves,
    );

    // 5️⃣ DISTRIBUTION
    final distribution = AttendanceDistribution(
      worked: summary.workingDays.toDouble(),
      leave: summary.totalLeaves.toDouble(),
      absent: summary.absentDays.toDouble(),
      late: summary.lateDays.toDouble(),
    );

    // 6️⃣ TODAY STATUS
    final todayStatus = await _loadTodayAttendance();

    // 7️⃣ MONTH WORKING DAYS BARS
    const int expectedMinutesPerDay = 540;

    print(
      '📊 Loading month working days bars (expected=$expectedMinutesPerDay min)',
    );

    final lastFiveDays = await _loadLastFiveDaysBars(expectedMinutesPerDay);

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
  ) async {
    const int maxAllowedMinutesPerDay = 650;

    final now = DateTime.now();

    final attendance = await attendanceRepo.fetchAttendance(
      month: now.month,
      year: now.year,
    );

    print('📦 Sessions fetched = ${attendance.sessions.length}');

    final Map<DateTime, int> workedByDate = {};

    for (final session in attendance.sessions) {
      final day = DateTime.parse(session.date);

      final dayKey = DateTime(day.year, day.month, day.day);

      int minutes = 0;

      if (session.durationMinutes != null) {
        minutes = session.durationMinutes!;
      } else if (session.checkOutTime == null) {
        minutes = DateTime.now().difference(session.checkInTime).inMinutes;
      }

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
