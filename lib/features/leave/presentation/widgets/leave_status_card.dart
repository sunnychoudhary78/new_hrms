import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/leave/data/models/leave_status_model.dart';
import 'package:lms/features/leave/presentation/providers/leave_details_provider.dart';
import 'package:lms/features/leave/presentation/widgets/leave_timeline_widget.dart';
import 'package:lms/core/widgets/status_badge.dart';
import 'package:lms/core/theme/app_design.dart';

class LeaveStatusCard extends ConsumerStatefulWidget {
  final LeaveStatus leave;
  final VoidCallback? onRevoke;
  final bool isInitiallyExpanded;

  const LeaveStatusCard({
    super.key,
    required this.leave,
    this.onRevoke,
    this.isInitiallyExpanded = false,
  });

  @override
  ConsumerState<LeaveStatusCard> createState() => _LeaveStatusCardState();
}

class _LeaveStatusCardState extends ConsumerState<LeaveStatusCard>
    with SingleTickerProviderStateMixin {
  late bool expanded;

  late AnimationController _controller;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();

    expanded = widget.isInitiallyExpanded;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (expanded) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'approved':
        return scheme.primary;
      case 'rejected':
        return scheme.error;
      case 'pending':
        return scheme.tertiary;
      case 'revoked':
        return scheme.outline;
      default:
        return scheme.primary;
    }
  }

  String _fmt(String raw) {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leave = widget.leave;
    final statusColor = _statusColor(leave.status, scheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: expanded
              ? scheme.primary.withOpacity(0.4)
              : scheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            tilePadding: const EdgeInsets.all(AppSpacing.md),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            onExpansionChanged: (v) {
              setState(() => expanded = v);
              v ? _controller.forward() : _controller.reverse();
            },
            title: Row(
              children: [
                /// STATUS DOT
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                /// LEAVE TYPE
                Expanded(
                  child: Text(
                    leave.leaveType ?? "Leave",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                /// STATUS BADGE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    leave.status.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              SizeTransition(
                sizeFactor: _expandAnim,
                child: Consumer(
                  builder: (context, ref, _) {
                    final detailsAsync = ref.watch(
                      leaveDetailsProvider(widget.leave.id),
                    );

                    return detailsAsync.when(
                      loading: () => const _PremiumShimmer(),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          "Failed to load details",
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                      data: (details) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.sm),

                            StatusBadge(status: details.status),

                            const SizedBox(height: AppSpacing.md),

                            Row(
                              children: [
                                Expanded(
                                  child: _DateBox(
                                    label: "FROM",
                                    value: _fmt(details.startDate),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _DateBox(
                                    label: "TO",
                                    value: _fmt(details.endDate),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.md),

                            _InfoRow(label: "Days", value: "${details.days}"),
                            _InfoRow(
                              label: "Manager",
                              value: details.managerName ?? "-",
                            ),

                            const SizedBox(height: AppSpacing.md),

                            _InfoBlock(
                              label: "Reason",
                              value: details.reason ?? "-",
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            LeaveTimelineWidget(histories: details.histories),

                            if (widget.onRevoke != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton.icon(
                                icon: const Icon(Icons.undo),
                                label: const Text("Revoke Leave"),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Revoke Leave"),
                                        content: const Text(
                                          "Are you sure you want to revoke this leave request?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Revoke"),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    widget.onRevoke!();

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Leave revocation requested",
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PREMIUM SHIMMER LOADER
class _PremiumShimmer extends StatefulWidget {
  const _PremiumShimmer();

  @override
  State<_PremiumShimmer> createState() => _PremiumShimmerState();
}

class _PremiumShimmerState extends State<_PremiumShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                scheme.surfaceContainerHighest,
                scheme.surface,
                scheme.surfaceContainerHighest,
              ],
              stops: [
                controller.value - 0.3,
                controller.value,
                controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;

  const _DateBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label), const SizedBox(height: 4), Text(value)],
    );
  }
}
