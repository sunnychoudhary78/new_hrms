import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/resignation/data/resignation_list_query.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class ResignationDashboardScreen extends ConsumerStatefulWidget {
  const ResignationDashboardScreen({super.key});

  @override
  ConsumerState<ResignationDashboardScreen> createState() =>
      _ResignationDashboardScreenState();
}

class _ResignationDashboardScreenState
    extends ConsumerState<ResignationDashboardScreen> {
  bool _isActionLoading = false;

  static String _normStatus(String status) => status.trim().toLowerCase();

  Future<void> _onRefresh() async {
    ref.invalidate(resignationDashboardProvider);
    await ref.read(resignationDashboardProvider.future);
  }

  Future<void> showActionDialog({
    required String id,
    required bool isApprove,
  }) async {
    if (_isActionLoading) return;

    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => _ResignationActionDialog(isApprove: isApprove),
    );
    if (remarks == null || !mounted) return;

    setState(() => _isActionLoading = true);

    try {
      ref
          .read(globalLoadingProvider.notifier)
          .showLoading(
            isApprove ? "Approving resignation..." : "Rejecting resignation...",
          );

      if (isApprove) {
        await ref.read(resignationActionProvider.notifier).approve(id, remarks);
      } else {
        await ref.read(resignationActionProvider.notifier).reject(id, remarks);
      }

      if (!mounted) return;

      final state = ref.read(resignationActionProvider);
      final role = ref.read(resignationRoleProvider);

      if (!state.hasError) {
        final msg = isApprove
            ? _approvalSuccessMessage(role)
            : "Request rejected — status updated";
        ref.read(globalLoadingProvider.notifier).showSuccess(msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.invalidate(resignationDashboardProvider);
          ref.invalidate(myResignationProvider);
        });
      } else {
        ref.read(globalLoadingProvider.notifier).showError('${state.error}');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  String _approvalSuccessMessage(ResignationRole role) {
    return switch (role) {
      ResignationRole.manager =>
        "Request approved — status is now Manager Approved.",
      ResignationRole.hod => "Request approved — status is now HOD Approved.",
      ResignationRole.hr => "Request approved — status is now HR Approved.",
      ResignationRole.employee => "Request approved.",
    };
  }

  @override
  Widget build(BuildContext context) {
    final resignationsAsync = ref.watch(resignationDashboardProvider);
    final listFilter = ref.watch(resignationListFilterProvider);
    final role = ref.watch(resignationRoleProvider);
    final roleTitle = switch (role) {
      ResignationRole.manager => "Manager",
      ResignationRole.hod => "HOD",
      ResignationRole.hr => "HR",
      ResignationRole.employee => "Employee",
    };
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();
    final actionBtnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
    );

    return Scaffold(
      appBar: const AppAppBar(title: "Resignation Dashboard"),

      body: Column(
        children: [
          _WorkflowHeader(roleTitle: roleTitle),
          const SizedBox(height: 4),
          if (role != ResignationRole.employee)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ResignationListQuery.values.map((q) {
                    final selected = listFilter == q;
                    return ChoiceChip(
                      label: Text(q.label),
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
                      ),
                      onSelected: (sel) {
                        if (sel) {
                          ref
                              .read(resignationListFilterProvider.notifier)
                              .select(q);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: resignationsAsync.when(
                loading: () => ListView(
                  physics: scrollPhysics,
                  children: const [
                    SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),

                error: (e, _) => ListView(
                  physics: scrollPhysics,
                  children: [
                    SizedBox(
                      height: 280,
                      child: Center(child: Text("Error: $e")),
                    ),
                  ],
                ),

                data: (list) {
                  if (role == ResignationRole.employee) {
                    return ListView(
                      physics: scrollPhysics,
                      children: const [
                        SizedBox(
                          height: 280,
                          child: Center(
                            child: Text(
                              "No dashboard access for employee role",
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  if (list.isEmpty) {
                    return ListView(
                      physics: scrollPhysics,
                      children: [
                        SizedBox(
                          height: 280,
                          child: Center(
                            child: Text(
                              listFilter == ResignationListQuery.all
                                  ? "No resignation requests"
                                  : "No requests for this filter — try All",
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: scrollPhysics,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final r = list[i];
                      final canTakeAction = _canTakeAction(
                        role: role,
                        status: r.status,
                      );

                      return PremiumCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.employeeName ?? "Employee",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  _StatusChip(status: r.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                r.reason,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _MetaPill(
                                    icon: Icons.route_rounded,
                                    text: _stageText(r.status),
                                  ),
                                  if (r.lastWorkingDate != null)
                                    _MetaPill(
                                      icon: Icons.calendar_today_rounded,
                                      text: "LWD: ${r.lastWorkingDate}",
                                    ),
                                ],
                              ),
                              if (canTakeAction) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          shape: actionBtnShape,
                                        ),
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => showActionDialog(
                                                id: r.id,
                                                isApprove: false,
                                              ),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text("Reject"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          shape: actionBtnShape,
                                        ),
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => showActionDialog(
                                                id: r.id,
                                                isApprove: true,
                                              ),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text("Approve"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canTakeAction({required ResignationRole role, required String status}) {
    final s = _normStatus(status);
    switch (role) {
      case ResignationRole.manager:
        return s == "pending";
      case ResignationRole.hod:
        return s == "manager approved";
      case ResignationRole.hr:
        return s == "hod approved";
      case ResignationRole.employee:
        return false;
    }
  }

  String _stageText(String status) {
    switch (_normStatus(status)) {
      case "pending":
        return "Waiting for Manager";
      case "manager approved":
        return "Waiting for HOD";
      case "hod approved":
        return "Waiting for HR";
      case "hr approved":
        return "Completed";
      case "rejected":
        return "Closed";
      case "withdrawn":
        return "Withdrawn by employee";
      default:
        return status;
    }
  }
}

class _ResignationActionDialog extends StatefulWidget {
  final bool isApprove;

  const _ResignationActionDialog({required this.isApprove});

  @override
  State<_ResignationActionDialog> createState() =>
      _ResignationActionDialogState();
}

class _ResignationActionDialogState extends State<_ResignationActionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _controller.text.trim().isNotEmpty;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 14 : 24),
      ),
      title: Text(
        widget.isApprove ? "Approve Resignation" : "Reject Resignation",
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: "Remarks *",
            helperText: "Required - visible to the employee and on record",
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: canProceed
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: Text(widget.isApprove ? "Approve" : "Reject"),
        ),
      ],
    );
  }
}

class _WorkflowHeader extends StatelessWidget {
  final String roleTitle;

  const _WorkflowHeader({required this.roleTitle});

  @override
  Widget build(BuildContext context) {
    return PremiumFeatureHeader(
      icon: Icons.assignment_return_outlined,
      title: "$roleTitle Approval Queue",
      subtitle: "Workflow: Employee -> Manager -> HOD -> HR",
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final color = switch (s) {
      "pending" => Colors.orange,
      "manager approved" || "hod approved" => Colors.indigo,
      "hr approved" => Colors.green,
      "rejected" => Colors.red,
      "withdrawn" => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };

    return PremiumStatusPill(label: status, color: color);
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isIOS ? 16 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}
