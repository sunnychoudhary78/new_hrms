// lib/core/notifications/notification_types.dart

/// Backend notification `type` values
abstract class NotificationTypes {
  // Leave
  static const leaveRequest = 'leave_request';
  static const leaveStatusUpdate = 'leave_status_update';
  static const leaveRevocationRequest = 'leave_revocation_request';
  static const leaveRequestApproved = 'leave_request_approved';
  static const leaveRequestRejected = 'leave_request_rejected';
  static const leaveRevoked = 'leave_revoked';

  // Attendance
  static const attendanceCheckin = 'attendance_checkin';
  static const attendanceCheckout = 'attendance_checkout';
  static const attendanceCorrectionRequested =
      'attendance_correction_requested';
  static const remoteWorkRequested = 'remote_work_requested';
  static const correctionApproved = 'correction_approved';
  static const attendanceAutoClosed = 'attendance_auto_closed';
  static const correctionRejected = 'correction_rejected';

  // Expenses
  static const expenseSubmitted = 'expense_submitted';
  static const expenseApproved = 'expense_approved';
  static const expenseRejected = 'expense_rejected';
  static const expenseProcessed = 'expense_processed';

  // Resignation
  static const resignationSubmitted = 'resignation_submitted';
  static const resignationApproved = 'resignation_approved';
  static const resignationRejected = 'resignation_rejected';
  static const resignationWithdrawn = 'resignation_withdrawn';

  // KRA
  static const kraAssigned = 'kra_assigned';
  static const kraSubmitted = 'kra_submitted';
  static const kraReviewed = 'kra_reviewed';
  static const kraCycleUpdated = 'kra_cycle_updated';

  // Fallback
  static const unknown = 'unknown';
}
