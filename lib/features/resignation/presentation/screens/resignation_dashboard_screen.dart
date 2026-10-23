import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/resignation/data/resignation_list_query.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: "Resignation Dashboard"),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: AppHeroBanner(
              icon: Icons.assignment_return_outlined,
              title: "$roleTitle approval queue",
              message: "Workflow: Employee → Manager → HOD → HR",
            ),
          ),
          if (role != ResignationRole.employee)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: ResignationListQuery.values.map((q) {
                    final selected = listFilter == q;
                    return AppFilterChip(
                      label: q.label,
                      selected: selected,
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

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.employeeName ?? "Employee",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: AppColors.title,
                                      ),
                                    ),
                                  ),
                                  AppStatusPill(label: r.status),
                                ],
                              ),
                              SizedBox(height: AppSpacing.sm + 2),
                              Text(
                                r.reason,
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: AppSpacing.sm + 2),
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
                                const SizedBox(height: AppSpacing.sm + 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppSecondaryButton(
                                        label: "Reject",
                                        icon: Icons.close_rounded,
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => showActionDialog(
                                                  id: r.id,
                                                  isApprove: false,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AppPrimaryButton(
                                        label: "Approve",
                                        icon: Icons.check_rounded,
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => showActionDialog(
                                                  id: r.id,
                                                  isApprove: true,
                                                ),
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
          decoration: appInputDecoration(
            labelText: "Remarks *",
            hintText: "Required — visible to the employee and on record",
          ).copyWith(
            helperText: "Required - visible to the employee and on record",
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

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.title,
            ),
          ),
        ],
      ),
    );
  }
}
