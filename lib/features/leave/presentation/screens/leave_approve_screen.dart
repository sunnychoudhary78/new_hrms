import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/features/home/presentation/widgets/app_drawer.dart';

import '../providers/leave_approve_provider.dart';
import '../widgets/leave_approve_appbar.dart';
import '../widgets/leave_pending_list.dart';
import '../widgets/leave_approved_list.dart';
import '../widgets/leave_rejected_list.dart';

class LeaveApproveScreen extends ConsumerStatefulWidget {
  const LeaveApproveScreen({super.key});

  @override
  ConsumerState<LeaveApproveScreen> createState() => _LeaveApproveScreenState();
}

class _LeaveApproveScreenState extends ConsumerState<LeaveApproveScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final async = ref.watch(leaveApproveProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,

      drawer: const AppDrawer(),

      appBar: const LeaveApproveAppBar(),

      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text(e.toString())),

        data: (requests) {
          /// Pending
          final pending = requests
              .where((e) => e.status.toLowerCase() == "pending")
              .toList();

          /// Approved
          final approved = requests
              .where((e) => e.status.toLowerCase() == "approved")
              .toList();

          /// Closed (Rejected, Revoked, Cancelled, Expired, etc)
          final closed = requests.where((e) {
            final s = e.status.toLowerCase();

            return s != "pending" && s != "approved";
          }).toList();

          return Column(
            children: [
              /// TAB BAR WITH COLORED BADGES
              Container(
                color: scheme.surface,

                child: TabBar(
                  controller: tabController,

                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,

                  tabs: [
                    /// PENDING TAB
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Pending"),

                          const SizedBox(width: 6),

                          _buildCountBadge(pending.length, scheme),
                        ],
                      ),
                    ),

                    /// APPROVED TAB
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Approved"),

                          const SizedBox(width: 6),

                          _buildCountBadge(approved.length, scheme),
                        ],
                      ),
                    ),

                    /// CLOSED TAB
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Closed"),

                          const SizedBox(width: 6),

                          _buildCountBadge(closed.length, scheme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              /// TAB CONTENT
              Expanded(
                child: TabBarView(
                  controller: tabController,

                  children: [
                    /// Pending list
                    LeavePendingList(
                      requests: pending,

                      onRefresh: () =>
                          ref.read(leaveApproveProvider.notifier).refresh(),

                      onApprove: (id, comment, dates) => ref
                          .read(leaveApproveProvider.notifier)
                          .approve(id, comment, dates),

                      onReject: (id, comment) => ref
                          .read(leaveApproveProvider.notifier)
                          .reject(id, comment),
                    ),

                    /// Approved list
                    LeaveApprovedList(
                      requests: approved,

                      onRefresh: () =>
                          ref.read(leaveApproveProvider.notifier).refresh(),
                    ),

                    /// Closed list (Rejected + Revoked + Cancelled)
                    LeaveRejectedList(
                      requests: closed,

                      onRefresh: () =>
                          ref.read(leaveApproveProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCountBadge(int count, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}
