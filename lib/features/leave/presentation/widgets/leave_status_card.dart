import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/leave/data/models/leave_status_model.dart';
import 'package:lms/features/leave/presentation/providers/leave_details_provider.dart';
import 'package:lms/features/leave/presentation/widgets/leave_timeline_widget.dart';

import 'package:lms/core/widgets/status_badge.dart';

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
      duration: const Duration(milliseconds: 400),
    );

    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (expanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'revoked':
        return const Color(0xFF64748B);
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
      duration: const Duration(milliseconds: 350),

      margin: const EdgeInsets.symmetric(vertical: 8),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withOpacity(0.9),
            scheme.surfaceContainerHighest.withOpacity(0.4),
          ],
        ),

        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(expanded ? 0.25 : 0.08),
            blurRadius: expanded ? 30 : 12,
            spreadRadius: expanded ? 1 : 0,
            offset: const Offset(0, 10),
          ),
        ],

        border: Border.all(
          color: statusColor.withOpacity(expanded ? 0.5 : 0.15),
          width: expanded ? 1.5 : 1,
        ),
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),

        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: expanded ? 6 : 2,
            sigmaY: expanded ? 6 : 2,
          ),

          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),

            child: ExpansionTile(
              initiallyExpanded: expanded,

              tilePadding: const EdgeInsets.all(20),

              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

              onExpansionChanged: (v) {
                setState(() => expanded = v);

                if (v) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },

              title: Row(
                children: [
                  /// STATUS INDICATOR
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    width: expanded ? 14 : 10,
                    height: expanded ? 14 : 10,

                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,

                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.7),
                          blurRadius: expanded ? 16 : 6,
                          spreadRadius: expanded ? 2 : 0,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  /// TYPE
                  Expanded(
                    child: Text(
                      leave.leaveType ?? "Leave",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  /// STATUS CHIP
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.15),
                          statusColor.withOpacity(0.05),
                        ],
                      ),

                      borderRadius: BorderRadius.circular(30),

                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),

                    child: Text(
                      leave.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "Failed to load details",
                            style: TextStyle(color: scheme.error),
                          ),
                        ),

                        data: (details) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const SizedBox(height: 12),

                              StatusBadge(status: details.status),

                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _DateBox(
                                      label: "FROM",
                                      value: _fmt(details.startDate),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DateBox(
                                      label: "TO",
                                      value: _fmt(details.endDate),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              _InfoRow(label: "Days", value: "${details.days}"),

                              _InfoRow(
                                label: "Manager",
                                value: details.managerName ?? "-",
                              ),

                              const SizedBox(height: 16),

                              _InfoBlock(
                                label: "Reason",
                                value: details.reason ?? "-",
                              ),

                              const SizedBox(height: 20),

                              LeaveTimelineWidget(histories: details.histories),

                              if (widget.onRevoke != null) ...[
                                const SizedBox(height: 20),

                                FilledButton.icon(
                                  onPressed: widget.onRevoke,
                                  icon: const Icon(Icons.undo),
                                  label: const Text("Revoke Leave"),
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
