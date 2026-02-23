import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/widgets/status_badge.dart';

import '../providers/leave_details_provider.dart';
import '../../data/models/leave_details_model.dart';
import '../widgets/leave_timeline_widget.dart';

class LeaveDetailsScreen extends ConsumerWidget {
  final String leaveRequestId;

  const LeaveDetailsScreen({super.key, required this.leaveRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final leaveAsync = ref.watch(leaveDetailsProvider(leaveRequestId));

    return Scaffold(
      appBar: AppBar(title: const Text("Leave Details")),

      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text("Failed to load leave\n$e")),

        data: (LeaveDetails leave) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Card(
              color: scheme.surfaceContainerLow,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    /// STATUS
                    Row(
                      children: [
                        const Text(
                          "Status:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(width: 10),

                        StatusBadge(status: leave.status),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// TYPE
                    Text("Leave Type: ${leave.leaveType ?? '-'}"),

                    const SizedBox(height: 12),

                    /// DAYS
                    Text("Days: ${leave.days}"),

                    const SizedBox(height: 12),

                    /// FROM
                    Text("From: ${leave.startDate}"),

                    const SizedBox(height: 6),

                    /// TO
                    Text("To: ${leave.endDate}"),

                    const SizedBox(height: 12),

                    /// MANAGER
                    Text("Manager: ${leave.managerName ?? '-'}"),

                    const SizedBox(height: 12),

                    /// REASON
                    Text("Reason: ${leave.reason ?? '-'}"),

                    const SizedBox(height: 24),

                    /// TIMELINE
                    LeaveTimelineWidget(histories: leave.histories),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.red;

      case "pending":
        return Colors.orange;

      case "revoked":
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }
}
