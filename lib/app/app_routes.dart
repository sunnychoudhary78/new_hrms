import 'package:flutter/material.dart';
import 'package:lms/core/screens/subscribtion_expired_screen.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/screens/my_corrections_screen.dart';
import 'package:lms/features/attendance/view_attendance/presentation/screens/view_attendance_screen.dart';
import 'package:lms/features/auth/presentation/screens/change_password_screen.dart';
import 'package:lms/features/auth/presentation/screens/forgot_passowrd_screen.dart';
import 'package:lms/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:lms/features/dashboard/presentation/screens/team_dashboard_screeen.dart';
import 'package:lms/features/leave/presentation/screens/leave_apply_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_approve_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_balance_screen.dart';
import 'package:lms/features/profile/presentation/screens/profile_screen.dart';
import 'package:lms/features/settings/presentation/screens/settings_screen.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/leave/presentation/screens/leave_status_screen.dart';
import '../features/attendance/mark_attendance/presentation/screens/mark_attendance_screen.dart';
import '../features/attendance/correction_attendance/presentation/screens/attendance_correction_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/home': (_) => const HomeScreen(),
    '/login': (_) => const LoginScreen(),
    '/profile': (_) => const ProfileScreen(),
    '/team-dashboard': (_) => const TeamDashboardScreen(),
    '/leave-balance': (_) => const LeaveBalanceScreen(),
    '/leave-apply': (_) => const LeaveApplyScreen(),
    '/leave-approve': (_) => const LeaveApproveScreen(),
    '/change-password': (_) => const ChangePasswordScreen(),
    '/view-attendance': (_) => const ViewAttendanceScreen(),
    '/leave-status': (_) => const LeaveStatusScreen(),
    '/mark-attendance': (_) => const MarkAttendanceScreen(),
    '/correct-attendance': (_) => const AttendanceCorrectionScreen(),
    '/view-corrections': (_) => const MyCorrectionsScreen(),
    '/notifications': (_) => const NotificationScreen(),
    '/settings': (_) => const ThemeSettingsScreen(),
    '/subscription-expired': (_) => const SubscriptionExpiredScreen(),

    // ✅ ADD THESE TWO
    '/forgot-password': (_) => const ForgotPasswordScreen(),

    '/reset-password': (context) {
      final email = ModalRoute.of(context)!.settings.arguments as String;
      return ResetPasswordScreen(email: email);
    },
  };
}
