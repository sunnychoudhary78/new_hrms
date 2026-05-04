// lib/core/notifications/notification_router.dart
import 'notification_action.dart';
import 'notification_types.dart';

class NotificationRouter {
  /// Convert backend push / API notification into app action
  static NotificationAction resolve({
    required String? type,
    required Map<String, dynamic>? data,
  }) {
    final t = (type ?? '').trim().toLowerCase();
    final payload = _payload(data);

    switch (t) {
      // ───────── LEAVE ─────────

      case NotificationTypes.leaveRequest:
      case NotificationTypes.leaveRevocationRequest:
        final leaveRequestId = _string(payload, 'leaveRequestId');
        if (leaveRequestId != null) {
          return OpenLeaveApproval(leaveRequestId: leaveRequestId);
        }
        return const OpenLeaveApproval(leaveRequestId: '');

      case NotificationTypes.leaveStatusUpdate:
      case NotificationTypes.leaveRequestApproved:
      case NotificationTypes.leaveRequestRejected:
      case NotificationTypes.leaveRevoked:
        final leaveRequestId = _string(payload, 'leaveRequestId');
        if (leaveRequestId != null) {
          return OpenLeaveStatus(leaveRequestId: leaveRequestId);
        }
        return const OpenNotifications();

      // ───────── ATTENDANCE ─────────

      case NotificationTypes.attendanceCheckin:
      case NotificationTypes.attendanceCheckout:
      case NotificationTypes.attendanceAutoClosed:
        return OpenAttendance(date: _string(payload, 'date'));

      case NotificationTypes.attendanceCorrectionRequested:
      case NotificationTypes.remoteWorkRequested:
      case NotificationTypes.correctionApproved:
      case NotificationTypes.correctionRejected:
        final correctionId = _string(payload, 'correctionId');
        if (correctionId != null) {
          return OpenAttendanceCorrection(correctionId: correctionId);
        }
        return const OpenNotifications();

      // ───────── EXPENSES ─────────

      case NotificationTypes.expenseSubmitted:
      case NotificationTypes.expenseApproved:
      case NotificationTypes.expenseRejected:
      case NotificationTypes.expenseProcessed:
        return const OpenExpenses(preferDashboard: true);

      // ───────── RESIGNATION ─────────

      case NotificationTypes.resignationSubmitted:
      case NotificationTypes.resignationApproved:
      case NotificationTypes.resignationRejected:
      case NotificationTypes.resignationWithdrawn:
        return const OpenResignation(preferDashboard: true);

      // ───────── KRA ─────────

      case NotificationTypes.kraAssigned:
      case NotificationTypes.kraSubmitted:
      case NotificationTypes.kraReviewed:
      case NotificationTypes.kraCycleUpdated:
        return const OpenKra();

      // ───────── DEFAULT ─────────

      default:
        // Safety net for newer backend notification types.
        if (t.contains('leave')) {
          final leaveRequestId = _string(payload, 'leaveRequestId');
          if (leaveRequestId != null && leaveRequestId.isNotEmpty) {
            return OpenLeaveStatus(leaveRequestId: leaveRequestId);
          }
          return const OpenNotifications();
        }
        if (t.contains('correction')) {
          final correctionId = _string(payload, 'correctionId');
          if (correctionId != null && correctionId.isNotEmpty) {
            return OpenAttendanceCorrection(correctionId: correctionId);
          }
          return const OpenAttendance();
        }
        if (t.contains('expense')) {
          return const OpenExpenses(preferDashboard: true);
        }
        if (t.contains('resignation')) {
          return const OpenResignation(preferDashboard: true);
        }
        if (t.contains('kra') || t.contains('kpi')) {
          return const OpenKra();
        }
        return const OpenNotifications();
    }
  }

  static Map<String, dynamic> _payload(Map<String, dynamic>? data) {
    final nested = data?['data'];
    if (nested is Map<String, dynamic>) {
      return {...?data, ...nested};
    }
    return data ?? const {};
  }

  static String? _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
