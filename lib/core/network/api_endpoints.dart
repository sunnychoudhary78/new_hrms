class ApiEndpoints {
  // ───────── ATTENDANCE ─────────
  static const String attendance = 'attendance';
  static const String attendanceSummary = 'attendance/summary';
  static const String checkIn = 'attendance/checkin';
  static const String checkOut = 'attendance/checkout';
  static const String attendanceCorrections = 'attendance/corrections';
  static const String attendanceCorrectionsManaged =
      'attendance/corrections/managed';
  static const String attendanceCorrectionsMy = 'attendance/corrections/my';
  static const String mobileAttendanceConfig = 'attendance/mobile-config';

  // ───────── COMPANY ─────────
  static const String companySettings = 'company-settings/my';

  // ───────── AUTH ─────────
  static const String login = 'auth/login';
  static const String sendOtp = 'auth/otp/send';
  static const String verifyOtp = 'auth/otp/verify';
  static const String permissions = 'auth/permissions';
  static const String changePassword = 'auth/change-password';
  static const String forgotPassword = 'auth/forgot-password';
  static const String resetPassword = 'auth/reset-password';
  static const String registerFcmToken = 'auth/register-fcm-token';
  static const String unregisterFcmToken = 'auth/unregister-fcm-token';

  // ───────── USER / EMPLOYEE ─────────
  static const String userDetails = 'employees/single';
  static const String teamDashboard = 'employees/team-dashboard';

  // ───────── PROFILE ─────────
  static const String profileImage = 'employee-photo/photo';

  // ───────── NOTIFICATIONS ─────────
  static const String notifications = 'notifications';
}
