import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/correction_attendance/presentation/providers/attendance_requests_provider.dart';
import '../../features/attendance/correction_attendance/presentation/providers/my_corrections_provider.dart';
import '../../features/attendance/view_attendance/presentation/providers/view_attendance_provider.dart';
import '../../features/dashboard/presentation/providers/team_attendance_provider.dart';
import '../../features/expenses/presentation/providers/expense_provider.dart';
import '../../features/kra/presentation/providers/kra_provider.dart';
import '../../features/leave/presentation/providers/leave_apply_provider.dart';
import '../../features/leave/presentation/providers/leave_approve_provider.dart';
import '../../features/leave/presentation/providers/leave_balance_provider.dart';
import '../../features/leave/presentation/providers/leave_details_provider.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';
import '../../features/resignation/presentation/providers/resignation_providers.dart';
import '../notifications/notification_action_notifier.dart';

/// Clears cached async/notifier state tied to the signed-in user. Call when
/// [userId] changes (AppRoot) or before [logout] (drawer) so lists and form
/// notifiers cannot flash another user's data.
void invalidateAllUserScopedData(WidgetRef ref) {
  ref.invalidate(myCorrectionsProvider);
  ref.invalidate(attendanceRequestsProvider);
  ref.invalidate(employeeAttendanceProvider);
  ref.invalidate(viewAttendanceProvider);
  ref.invalidate(notificationProvider);
  ref.invalidate(unreadCountProvider);
  ref.invalidate(notificationActionProvider);
  ref.invalidate(leaveApplyProvider);
  ref.invalidate(leaveBalanceProvider);
  ref.invalidate(leaveApproveProvider);
  ref.invalidate(leaveDetailsProvider);

  ref.invalidate(myExpensesProvider);
  ref.invalidate(expenseDashboardStatusFilterProvider);
  ref.invalidate(expenseDashboardProvider);
  ref.invalidate(createExpenseProvider);

  ref.invalidate(myKrasProvider);
  ref.invalidate(managedKrasProvider);
  ref.invalidate(kraTeamMembersProvider);
  ref.invalidate(kraCyclesProvider);
  ref.invalidate(kraActiveCycleProvider);
  ref.invalidate(kraActionProvider);
  for (final mode in KraReviewMode.values) {
    ref.invalidate(kraEvaluationsProvider(mode));
  }

  ref.invalidate(myResignationProvider);
  ref.invalidate(resignationListFilterProvider);
  ref.invalidate(resignationDashboardProvider);
}
