class TeamDashboard {
  final int total;
  final int present;
  final int absent;
  final List<LastSevenDay> lastSevenDays;
  final List<TeamEmployee> employees;

  TeamDashboard({
    required this.total,
    required this.present,
    required this.absent,
    required this.lastSevenDays,
    required this.employees,
  });

  factory TeamDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};

    return TeamDashboard(
      total: stats['total'] ?? 0,
      present: stats['present'] ?? 0,
      absent: stats['absent'] ?? 0,
      lastSevenDays: (stats['lastSevenDays'] as List? ?? [])
          .map((e) => LastSevenDay.fromJson(e))
          .toList(),
      employees: (json['employees'] as List? ?? [])
          .map((e) => TeamEmployee.fromJson(e))
          .toList(),
    );
  }

  double get presentPercentage {
    if (total == 0) return 0;
    return (present / total) * 100;
  }
}

class LastSevenDay {
  final String date;
  final int present;
  final int absent;
  final int total;

  LastSevenDay({
    required this.date,
    required this.present,
    required this.absent,
    required this.total,
  });

  factory LastSevenDay.fromJson(Map<String, dynamic> json) {
    return LastSevenDay(
      date: json['date'] ?? '',
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}

class TeamEmployee {
  final String name;
  final String email;
  final String contact;
  final String employeeId;
  final String userId;
  final bool isPresent;
  final String managerName;
  final String? profilePicture;

  final AttendanceSummary? attendanceSummary;

  TeamEmployee({
    required this.name,
    required this.email,
    required this.contact,
    required this.employeeId,
    required this.userId,
    required this.isPresent,
    required this.managerName,
    required this.profilePicture,
    required this.attendanceSummary,
  });

  factory TeamEmployee.fromJson(Map<String, dynamic> json) {
    return TeamEmployee(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      contact: json['contact'] ?? '',
      employeeId: json['employee_id'] ?? '',
      userId: json['user_id'] ?? '',
      isPresent: json['is_present'] ?? false,
      managerName: json['manager_name'] ?? '',
      profilePicture: json['profile_picture'],
      attendanceSummary: json['attendanceSummary'] != null
          ? AttendanceSummary.fromJson(
              json['attendanceSummary']['summary'] ?? {},
            )
          : null,
    );
  }

  factory TeamEmployee.fromNotification(Map<String, dynamic> sender) {
    return TeamEmployee(
      name: sender['name'] ?? 'Employee',
      email: sender['email'] ?? '',
      contact: '',
      employeeId: sender['id'] ?? '',
      userId: sender['id'] ?? '',
      isPresent: false,
      managerName: '',
      profilePicture: null,
      attendanceSummary: null,
    );
  }

  // ==========================
  // 🔥 DERIVED METRICS
  // ==========================

  double get attendanceRate {
    if (attendanceSummary == null) return 0;

    final totalTracked =
        attendanceSummary!.workingDays +
        attendanceSummary!.absentDays +
        attendanceSummary!.totalLeaves;

    if (totalTracked == 0) return 0;

    return (attendanceSummary!.workingDays / totalTracked) * 100;
  }

  double get workingHoursCompleted {
    if (attendanceSummary == null) return 0;

    return attendanceSummary!.totalMinutes / 60;
  }

  bool get needsAttention {
    if (attendanceSummary == null) return false;

    return attendanceSummary!.lateDays >= 3 ||
        attendanceSummary!.absentDays >= 3;
  }
}

class AttendanceSummary {
  final String month;
  final double workingDays;
  final int lateDays;
  final int totalMinutes;
  final double totalLeaves;
  final int absentDays;
  final double payableDays;
  final int totalWeekoffs;
  final int totalHolidays;
  final int expectedWorkingHours;

  AttendanceSummary({
    required this.month,
    required this.workingDays,
    required this.lateDays,
    required this.totalMinutes,
    required this.totalLeaves,
    required this.absentDays,
    required this.payableDays,
    required this.totalWeekoffs,
    required this.totalHolidays,
    required this.expectedWorkingHours,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      month: json['month'] ?? '',

      workingDays: (json['workingDays'] as num?)?.toDouble() ?? 0.0,

      lateDays: (json['lateDays'] as num?)?.toInt() ?? 0,

      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,

      totalLeaves: (json['totalLeaves'] as num?)?.toDouble() ?? 0.0,

      absentDays: (json['absentDays'] as num?)?.toInt() ?? 0,

      payableDays: (json['payableDays'] as num?)?.toDouble() ?? 0.0,

      totalWeekoffs: (json['totalWeekoffs'] as num?)?.toInt() ?? 0,

      totalHolidays: (json['totalHolidays'] as num?)?.toInt() ?? 0,

      expectedWorkingHours:
          (json['expectedWorkingHours'] as num?)?.toInt() ?? 0,
    );
  }

  double get completionPercentage {
    if (expectedWorkingHours == 0) return 0;
    return (totalMinutes / (expectedWorkingHours * 60)) * 100;
  }
}

class Holiday {
  final String date;
  final String name;

  Holiday({required this.date, required this.name});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(date: json['date'] ?? '', name: json['name'] ?? '');
  }
}
