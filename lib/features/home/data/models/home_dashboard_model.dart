/// Home Dashboard – Aggregated data model
///
/// This model is the SINGLE source of truth for Home screen.
/// UI must never do calculations — only display values.

class HomeDashboardModel {
  final String userName;
  final String designation;

  /// ✅ NEW: profile image (nullable)
  final String? profileImageUrl;

  final AttendanceOverview attendance;
  final HomeStats stats;
  final AttendanceDistribution distribution;
  final TodayAttendanceStatus todayStatus;
  final List<WeeklyAttendanceBar> lastFiveDays;

  const HomeDashboardModel({
    required this.userName,
    required this.designation,
    required this.profileImageUrl,
    required this.attendance,
    required this.stats,
    required this.distribution,
    required this.todayStatus,
    required this.lastFiveDays,
  });

  factory HomeDashboardModel.empty() {
    return HomeDashboardModel(
      userName: '',
      designation: '',
      profileImageUrl: null,
      attendance: const AttendanceOverview(
        workedMinutes: 0,
        expectedMinutes: 0,
      ),
      stats: const HomeStats(
        payableDays: 0,
        lateDays: 0,
        absentDays: 0,
        totalLeaves: 0,
      ),
      distribution: const AttendanceDistribution(
        worked: 0,
        leave: 0,
        absent: 0,
        late: 0,
      ),
      todayStatus: const TodayAttendanceStatus(isCheckedIn: false),
      lastFiveDays: const [],
    );
  }
}

//
// ─────────────────────────────────────────────
// TODAY ATTENDANCE STATUS (CARD)
// ─────────────────────────────────────────────
//

class TodayAttendanceStatus {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  const TodayAttendanceStatus({
    required this.isCheckedIn,
    this.checkInTime,
    this.checkOutTime,
  });
}

//
// ─────────────────────────────────────────────
// ATTENDANCE OVERVIEW (BAR CHART)
// Worked vs Expected
// ─────────────────────────────────────────────
//

class AttendanceOverview {
  final int workedMinutes;
  final int expectedMinutes;

  const AttendanceOverview({
    required this.workedMinutes,
    required this.expectedMinutes,
  });

  /// Convert minutes → hours (1 decimal)
  double get workedHours =>
      double.parse((workedMinutes / 60).toStringAsFixed(1));

  double get expectedHours =>
      double.parse((expectedMinutes / 60).toStringAsFixed(1));

  /// % completion (0–100)
  double get progressPercent {
    if (expectedMinutes == 0) return 0;
    return (workedMinutes / expectedMinutes * 100).clamp(0, 100).toDouble();
  }
}

//
// ─────────────────────────────────────────────
// QUICK STATS (CARDS)
// ─────────────────────────────────────────────
//

class HomeStats {
  final double payableDays;
  final int lateDays;
  final int absentDays;
  final int totalLeaves;

  const HomeStats({
    required this.payableDays,
    required this.lateDays,
    required this.absentDays,
    required this.totalLeaves,
  });
}

//
// ─────────────────────────────────────────────
// PIE CHART – DISTRIBUTION
// ─────────────────────────────────────────────
//

class AttendanceDistribution {
  final double worked;
  final double leave;
  final double absent;
  final double late;

  const AttendanceDistribution({
    required this.worked,
    required this.leave,
    required this.absent,
    required this.late,
  });

  double get total => worked + leave + absent + late;

  double percent(double value) {
    if (total == 0) return 0;
    return (value / total * 100).toDouble();
  }
}

/// ─────────────────────────────────────────────
/// LAST 5 WORKING DAYS (BAR CHART)
/// ─────────────────────────────────────────────

class WeeklyAttendanceBar {
  final DateTime date;
  final int workedMinutes;
  final int expectedMinutes;
  final bool isCapped;

  const WeeklyAttendanceBar({
    required this.date,
    required this.workedMinutes,
    required this.expectedMinutes,
    this.isCapped = false,
  });
}
