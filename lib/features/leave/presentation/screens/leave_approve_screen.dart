import 'package:flutter/foundation.dart';
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bannerRadius = isIOS ? 14.0 : 18.0;
    final tabShellRadius = isIOS ? 12.0 : 14.0;
    final errRadius = isIOS ? 12.0 : 14.0;

    final async = ref.watch(leaveApproveProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,

      drawer: const AppDrawer(),

      appBar: const LeaveApproveAppBar(),

      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(errRadius),
            ),
            child: Text(
              "Unable to load leave approvals.\n$e",
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),

        data: (requests) {
          /// Pending
          final pending = requests.where((e) {
            final s = e.status.toLowerCase();

            return s == "pending" || s == "revocationrequested";
          }).toList();

          /// Approved
          final approved = requests
              .where((e) => e.status.toLowerCase() == "approved")
              .toList();

          /// Closed (Rejected, Revoked, Cancelled, Expired, etc)
          final closed = requests.where((e) {
            final s = e.status.toLowerCase();

            return s != "pending" &&
                s != "approved" &&
                s != "revocationrequested";
          }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(bannerRadius),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Leave approval queue",
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Review pending, approved and closed leave requests.",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricChip(
                            label: "Pending",
                            count: pending.length,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            label: "Approved",
                            count: approved.length,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            label: "Closed",
                            count: closed.length,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              /// TAB BAR WITH COLORED BADGES
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(tabShellRadius),
                  border: Border.all(color: scheme.outlineVariant),
                ),

                child: TabBar(
                  controller: tabController,

                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,

                  tabs: [
                    /// PENDING TAB
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Pending"),

                            const SizedBox(width: 6),

                            _buildCountBadge(pending.length, scheme),
                          ],
                        ),
                      ),
                    ),

                    /// APPROVED TAB
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Approved"),

                            const SizedBox(width: 6),

                            _buildCountBadge(approved.length, scheme),
                          ],
                        ),
                      ),
                    ),

                    /// CLOSED TAB
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Closed"),

                            const SizedBox(width: 6),

                            _buildCountBadge(closed.length, scheme),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              /// TAB CONTENT
              Expanded(
                child: TabBarView(
                  physics: isIOS
                      ? const BouncingScrollPhysics()
                      : const ClampingScrollPhysics(),
                  controller: tabController,

                  children: [
                    /// Pending list
                    LeavePendingList(
                      requests: pending,

                      onRefresh: () =>
                          ref.read(leaveApproveProvider.notifier).refresh(),

                      onApprove: (id, action, comment, approvedDatesInput) =>
                          ref
                              .read(leaveApproveProvider.notifier)
                              .approve(id, action, comment, approvedDatesInput),

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

class _MetricChip extends StatelessWidget {
  final String label;
  final int count;

  const _MetricChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              color: scheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
