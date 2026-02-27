class ApiEndpoints {
  static const String attendance = '/attendance';
  static const String attendanceSummary = '/attendance/summary';
  static const String checkIn = '/attendance/checkin';
  static const String checkOut = '/attendance/checkout';
  static const String attendanceCorrections = '/attendance/corrections';
  static const String attendanceCorrectionsManaged =
      '/attendance/corrections/managed';
  static const String attendanceCorrectionsMy = '/attendance/corrections/my';
  static const String companySettings = '/company-settings/my';

  static const String login = '/auth/login';
  static const String permissions = '/auth/permissions';
  static const String userDetails = '/employees/single';

  static const String profileImage = '/employee-photo';
  static const String teamDashboard = '/employees/team-dashboard';

  static const String notifications = '/notifications';
  static const mobileAttendanceConfig = "/attendance/mobile-config";
}
