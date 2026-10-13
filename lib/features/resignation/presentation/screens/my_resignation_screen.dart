import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/resignation/data/models/resignation_model.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

class MyResignationScreen extends ConsumerStatefulWidget {
  const MyResignationScreen({super.key});

  @override
  ConsumerState<MyResignationScreen> createState() =>
      _MyResignationScreenState();
}

class _MyResignationScreenState extends ConsumerState<MyResignationScreen> {
  final reasonController = TextEditingController();
  final dateController = TextEditingController();

  bool _isSubmitting = false;

  /// Employee may withdraw until HR gives final approval (pending → manager → HOD).
  static bool _canWithdrawResignation(String status) {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'manager approved' || s == 'hod approved';
  }

  /// 📅 DATE PICKER
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {});
    }
  }

  /// 🚀 SUBMIT
  Future<void> submit() async {
    if (_isSubmitting) return;

    if (reasonController.text.trim().isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError('Reason / remarks are required to submit your request');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(resignationActionProvider.notifier)
          .submit(
            reason: reasonController.text.trim(),
            lastWorkingDate: dateController.text.isEmpty
                ? null
                : dateController.text,
          );

      final state = ref.read(resignationActionProvider);

      if (!state.hasError) {
        ref
            .read(globalLoadingProvider.notifier)
            .showSuccess('Resignation submitted — status is now pending');

        reasonController.clear();
        dateController.clear();

        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.pop(context);
          }
        });
        ref.invalidate(myResignationProvider);
        ref.invalidate(resignationDashboardProvider);
      } else {
        ref.read(globalLoadingProvider.notifier).showError('${state.error}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 🔁 WITHDRAW
  Future<void> withdraw(String id) async {
    await ref.read(resignationActionProvider.notifier).withdraw(id);
    if (!mounted) return;
    final state = ref.read(resignationActionProvider);
    if (state.hasError) {
      ref.read(globalLoadingProvider.notifier).showError('${state.error}');
      return;
    }
    ref
        .read(globalLoadingProvider.notifier)
        .showSuccess('Resignation withdrawn');
    ref.invalidate(myResignationProvider);
    ref.invalidate(resignationDashboardProvider);
  }

  /// 📦 OPEN FORM
  void openForm() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: isIOS,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isIOS ? 14 : 24),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: SizedBox(height: screenHeight * 0.72, child: _buildForm()),
      ),
    );
  }

  Future<void> _refreshMyResignation() async {
    ref.invalidate(myResignationProvider);
    await ref.read(myResignationProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final resignationAsync = ref.watch(myResignationProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppAppBar(
        title: "My Resignation",
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              splashFactory: isIOS
                  ? NoSplash.splashFactory
                  : InkSplash.splashFactory,
            ),
            onPressed: _refreshMyResignation,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshMyResignation,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: scrollPhysics,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: resignationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),

                error: (e, _) => Center(child: Text("Error: $e")),

                data: (resignation) {
                  if (resignation == null) {
                    return Padding(
                      padding: appScreenPadding,
                      child: Center(
                        child: AppSectionCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIconBadge(
                                icon: Icons.assignment_outlined,
                                size: 56,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "No active resignation",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.title,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Create a resignation request only when you are ready to start the approval workflow.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 16),
                              AppPrimaryButton(
                                label: "Apply Resignation",
                                icon: Icons.edit_note_rounded,
                                onPressed: openForm,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return _buildStatus(resignation);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= FORM =================
  Widget _buildForm() {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: isIOS
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Container(
            width: 46,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const AppSectionTitle("Apply Resignation"),
          const SizedBox(height: 6),
          const Text(
            "This request will move to Manager, then HOD, then HR for final approval.",
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AppHeroBanner(
            icon: Icons.lock_outline_rounded,
            message:
                "Reason and remarks become part of the official approval record.",
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle("Request Details"),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  minLines: 6,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: appInputDecoration(
                    labelText: "Reason / remarks *",
                    hintText:
                        "Required — this text is part of the approval record",
                  ).copyWith(alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  textInputAction: TextInputAction.done,
                  decoration: appInputDecoration(
                    labelText: "Last Working Date",
                    hintText: "Select expected last working day",
                    prefixIcon: Icons.calendar_today,
                  ),
                  onTap: pickDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppPrimaryButton(
            label: "Submit Request",
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : submit,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(ResignationModel resignation) {
    final status = resignation.status;
    bool canApplyAgain = status == "Rejected" || status == "Withdrawn";

    String timelineText() {
      switch (status) {
        case "Pending":
          return "Waiting for Manager approval";
        case "Manager Approved":
          return "Manager approved, waiting for HOD";
        case "HOD Approved":
          return "HOD approved, waiting for HR";
        case "HR Approved":
          return "Final approval completed by HR";
        case "Rejected":
          return "Request rejected. You can apply again";
        case "Withdrawn":
          return "Request withdrawn by you";
        default:
          return "Request is being processed";
      }
    }

    return Padding(
      padding: appScreenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeroBanner(
            icon: Icons.assignment_return_outlined,
            title: "Resignation workflow",
            message: "Employee → Manager → HOD → HR",
          ),
          const SizedBox(height: 14),
          AppSectionCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkflowStepper(status: status),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppStatusPill(label: status),
                    if (resignation.lastWorkingDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softFill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          "LWD: ${resignation.lastWorkingDate}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.title,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const AppSectionTitle("Reason / remarks"),
                const SizedBox(height: 6),
                Text(
                  resignation.reason,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timelineText(),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_canWithdrawResignation(status))
            AppSecondaryButton(
              label: "Withdraw Request",
              icon: Icons.undo_rounded,
              onPressed: () => withdraw(resignation.id),
            ),
          if (_canWithdrawResignation(status)) const SizedBox(height: 10),
          if (canApplyAgain)
            AppPrimaryButton(
              label: "Apply Again",
              icon: Icons.refresh_rounded,
              onPressed: openForm,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    reasonController.dispose();
    dateController.dispose();
    super.dispose();
  }
}

class _WorkflowStepper extends StatelessWidget {
  final String status;
  const _WorkflowStepper({required this.status});

  int _currentStep() {
    switch (status) {
      case "Pending":
        return 0;
      case "Manager Approved":
        return 1;
      case "HOD Approved":
        return 2;
      case "HR Approved":
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ["Employee", "Manager", "HOD", "HR"];
    final step = _currentStep();
    final isClosed = status == "Rejected" || status == "Withdrawn";

    if (isClosed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              status == "Rejected" ? Icons.close_rounded : Icons.undo_rounded,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == "Rejected"
                    ? "Workflow closed as rejected"
                    : "Workflow closed as withdrawn",
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(steps.length, (index) {
            final done = index <= step;
            final isLast = index == steps.length - 1;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : AppColors.softFill,
                      border: done
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.circle_outlined,
                      size: 15,
                      color: done ? Colors.white : AppColors.muted,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: index < step
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps
              .map(
                (label) => Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
