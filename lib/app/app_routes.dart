import 'package:flutter/material.dart';
import 'package:lms/core/screens/subscribtion_expired_screen.dart';

// AUTH
import 'package:lms/features/auth/presentation/screens/change_password_screen.dart';
import 'package:lms/features/auth/presentation/screens/forgot_passowrd_screen.dart';
import 'package:lms/features/auth/presentation/screens/login_screen.dart';
import 'package:lms/features/auth/presentation/screens/otp_login_screen.dart';
import 'package:lms/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:lms/features/expenses/presentation/screens/expense_details_screen.dart';

// HOME
import '../features/home/presentation/screens/home_screen.dart';

// PROFILE
import 'package:lms/features/profile/presentation/screens/profile_screen.dart';

// DASHBOARD
import 'package:lms/features/dashboard/presentation/screens/team_dashboard_screeen.dart';

// LEAVE
import 'package:lms/features/leave/presentation/screens/leave_apply_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_approve_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_balance_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_status_screen.dart';

// ATTENDANCE
import 'package:lms/features/attendance/mark_attendance/presentation/screens/mark_attendance_screen.dart';
import 'package:lms/features/attendance/view_attendance/presentation/screens/view_attendance_screen.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/screens/attendance_correction_screen.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/screens/my_corrections_screen.dart';

// NOTIFICATIONS
import 'package:lms/features/notifications/presentation/screens/notifications_screen.dart';

// SETTINGS
import 'package:lms/features/settings/presentation/screens/settings_screen.dart';

// PAYSLIP
import 'package:lms/features/payslip/presentation/screens/payslip_list_screen.dart';

// POLICIES
import 'package:lms/features/policy/presentation/screens/policy_screen.dart';

// KRA / KPI
import 'package:lms/features/kra/presentation/screens/kra_dashboard_screen.dart';

// ================= EXPENSES =================
import 'package:lms/features/expenses/data/models/expense_model.dart';
import 'package:lms/features/expenses/presentation/screens/my_expenses_screen.dart';
import 'package:lms/features/expenses/presentation/screens/create_expense_screen.dart';

// 👉 NEW (you will create this)
import 'package:lms/features/expenses/presentation/screens/expenses_dashboard_screen.dart';

// ================= RESIGNATION =================
// 👉 YOU WILL CREATE THESE
import 'package:lms/features/resignation/presentation/screens/my_resignation_screen.dart';
import 'package:lms/features/resignation/presentation/screens/resignation_dashboard_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    // ================= CORE =================
    '/home': (_) => const HomeScreen(),
    '/login': (_) => const LoginScreen(),
    '/login-otp': (_) => const OtpLoginScreen(),

    // ================= PROFILE =================
    '/profile': (_) => const ProfileScreen(),

    // ================= DASHBOARD =================
    '/team-dashboard': (_) => const TeamDashboardScreen(),

    // ================= LEAVE =================
    '/leave-balance': (_) => const LeaveBalanceScreen(),
    '/leave-apply': (_) => const LeaveApplyScreen(),
    '/leave-status': (_) => const LeaveStatusScreen(),
    '/leave-approve': (_) => const LeaveApproveScreen(),

    // ================= ATTENDANCE =================
    '/mark-attendance': (_) => const MarkAttendanceScreen(),
    '/view-attendance': (_) => const ViewAttendanceScreen(),
    '/view-corrections': (_) => const MyCorrectionsScreen(),
    '/correct-attendance': (_) => const AttendanceCorrectionScreen(),

    // ================= EXPENSES (UPDATED) =================

    // Employee
    "/expenses/my": (_) => const MyExpensesScreen(),

    // Create (optional [ExpenseClaim] arguments = edit draft)
    "/expenses/create": (context) {
      final args = ModalRoute.of(context)!.settings.arguments;
      final edit = args is ExpenseClaim ? args : null;
      return CreateExpenseScreen(editClaim: edit);
    },

    "/expenses/detail": (_) => const ExpenseDetailScreen(),

    // ✅ NEW SINGLE DASHBOARD
    "/expenses-dashboard": (_) => const ExpensesDashboardScreen(),

    // ================= RESIGNATION (NEW) =================

    // Employee
    "/resignation/my": (_) => const MyResignationScreen(),

    // Manager / HOD / HR
    "/resignation-dashboard": (_) => const ResignationDashboardScreen(),

    // ================= PAYSLIP =================
    '/payslip': (_) => const PayslipListScreen(),

    // ================= POLICIES =================
    '/policies': (_) => const PolicyScreen(),

    // ================= KRA / KPI =================
    '/kra': (_) => const KraDashboardScreen(),

    // ================= SETTINGS =================
    '/settings': (_) => const ThemeSettingsScreen(),

    // ================= AUTH EXTRA =================
    '/change-password': (_) => const ChangePasswordScreen(),
    '/forgot-password': (_) => const ForgotPasswordScreen(),

    '/reset-password': (context) {
      final email = ModalRoute.of(context)!.settings.arguments as String;
      return ResetPasswordScreen(email: email);
    },

    // ================= NOTIFICATIONS =================
    '/notifications': (_) => const NotificationScreen(),

    // ================= SUBSCRIPTION =================
    '/subscription-expired': (_) => const SubscriptionExpiredScreen(),
  };
}
