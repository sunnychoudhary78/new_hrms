import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/dashboard/presentation/screens/employee_attendence_calender_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_details_screen.dart';
import 'package:lms/features/leave/presentation/screens/leave_status_screen.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lms/features/notifications/presentation/screens/notification_details_screen.dart';
import 'package:lms/features/notifications/presentation/widgets/notification_tile.dart';

import 'package:lms/features/dashboard/data/models/team_dashboard_model.dart';

class NotificationList extends ConsumerWidget {
  final List<dynamic> notifications;

  const NotificationList({super.key, required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// ✅ GET AUTH STATE
    final authState = ref.watch(authProvider);

    /// ✅ GET PERMISSIONS LIST
    final permissions = authState.permissions;

    /// ✅ DEBUG PRINT PERMISSIONS
    print("========= USER PERMISSIONS =========");
    print(permissions);
    print("====================================");

    /// ✅ CHECK IF USER IS MANAGER (same logic as drawer)
    final bool canViewTeamAttendance = permissions.contains(
      'leave.request.approve',
    );

    print("Can view team attendance: $canViewTeamAttendance");

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final n = notifications[index];

        final String id = n["id"];

        final bool isUnread = n["is_read"] == false;

        final DateTime createdAt =
            DateTime.tryParse(n["createdAt"] ?? "") ?? DateTime.now();

        return Dismissible(
          key: ValueKey(id),

          direction: DismissDirection.endToStart,

          /// DELETE BACKGROUND
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 26),
          ),

          /// CONFIRM DELETE
          confirmDismiss: (_) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("Delete notification"),
                  content: const Text(
                    "Are you sure you want to delete this notification?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            );

            return confirm ?? false;
          },

          /// DELETE ACTION
          onDismissed: (_) {
            ref.read(notificationProvider.notifier).deleteNotification(id);
          },

          child: NotificationTile(
            icon: _iconForType(n["type"]),

            title: n["title"] ?? "Notification",

            subtitle: n["message"] ?? "",

            time: _formatTime(createdAt),

            isUnread: isUnread,

            /// ✅ TAP HANDLER WITH FULL DEBUG
            onTap: () {
              /// MARK AS READ
              if (isUnread) {
                ref.read(notificationProvider.notifier).markAsRead(id);
              }

              final notificationType = n["type"]?.toString();
              final senderRaw = n["sender"];
              final data = n["data"];

              debugPrint("🔔 Notification tapped");
              debugPrint("ID: $id");
              debugPrint("Type: $notificationType");
              debugPrint("Data: $data");

              /// =====================================================
              /// MANAGER FLOW → Open Employee Attendance Calendar
              /// =====================================================
              if (canViewTeamAttendance) {
                if (senderRaw is Map<String, dynamic>) {
                  try {
                    final employee = TeamEmployee.fromNotification(senderRaw);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeAttendanceCalendarScreen(
                          employee: employee,
                        ),
                      ),
                    );

                    return;
                  } catch (e) {
                    debugPrint("❌ Failed to parse employee: $e");
                  }
                }
              }

              /// =====================================================
              /// EMPLOYEE FLOW
              /// =====================================================

              /// CASE 1: Leave Status Update → Open Leave Details
              if (notificationType == "LEAVE_STATUS_UPDATE" &&
                  data is Map<String, dynamic>) {
                final leaveId = data["leaveRequestId"]?.toString();

                if (leaveId != null && leaveId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeaveStatusScreen(expandLeaveId: leaveId),
                    ),
                  );

                  return;
                }
              }

              /// CASE 2: Leave Request Created → also open leave details
              if (notificationType == "LEAVE_REQUEST" &&
                  data is Map<String, dynamic>) {
                final leaveId = data["leaveRequestId"]?.toString();

                if (leaveId != null && leaveId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeaveStatusScreen(expandLeaveId: leaveId),
                    ),
                  );

                  return;
                }
              }

              /// CASE 3: Leave Revocation Request
              if (notificationType == "LEAVE_REVOCATION_REQUEST" &&
                  data is Map<String, dynamic>) {
                final leaveId = data["leaveRequestId"]?.toString();

                if (leaveId != null && leaveId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeaveStatusScreen(expandLeaveId: leaveId),
                    ),
                  );

                  return;
                }
              }

              /// =====================================================
              /// DEFAULT FALLBACK → Open Generic Notification Details
              /// =====================================================
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationDetailsScreen(notification: n),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// ICON RESOLVER
  IconData _iconForType(String? type) {
    switch (type) {
      case 'attendance_auto_closed':
        return Icons.timer_off;

      case 'attendance_checkin':
        return Icons.login;

      case 'attendance_checkout':
        return Icons.logout;

      case 'LEAVE_REQUEST':
        return Icons.event_note;

      default:
        return Icons.notifications;
    }
  }

  /// TIME FORMATTER
  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'just now';

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

    if (diff.inHours < 24) return '${diff.inHours}h ago';

    if (diff.inDays == 1) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }
}
