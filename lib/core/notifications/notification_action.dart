// lib/core/notifications/notification_action.dart

sealed class NotificationAction {
  const NotificationAction();
}

/// Open leave status screen
class OpenLeaveStatus extends NotificationAction {
  final String leaveRequestId;

  const OpenLeaveStatus({required this.leaveRequestId});
}

/// Open leave approval screen (manager side)
class OpenLeaveApproval extends NotificationAction {
  final String leaveRequestId;

  const OpenLeaveApproval({required this.leaveRequestId});
}

/// Open attendance screen
class OpenAttendance extends NotificationAction {
  final String? date; // yyyy-MM-dd

  const OpenAttendance({this.date});
}

/// Open attendance correction screen
class OpenAttendanceCorrection extends NotificationAction {
  final String correctionId;

  const OpenAttendanceCorrection({required this.correctionId});
}

/// Open expenses module (my list or dashboard)
class OpenExpenses extends NotificationAction {
  final bool preferDashboard;

  const OpenExpenses({this.preferDashboard = false});
}

/// Open resignation module (my request or approval dashboard)
class OpenResignation extends NotificationAction {
  final bool preferDashboard;

  const OpenResignation({this.preferDashboard = false});
}

/// Open KRA dashboard
class OpenKra extends NotificationAction {
  const OpenKra();
}

/// Open notifications list (fallback)
class OpenNotifications extends NotificationAction {
  const OpenNotifications();
}

/// Do nothing (safety)
class NoAction extends NotificationAction {
  const NoAction();
}
