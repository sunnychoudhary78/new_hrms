import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/resignation/data/models/resignation_model.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Resignation"),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshMyResignation,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshMyResignation,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: resignationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),

                error: (e, _) => Center(child: Text("Error: $e")),

                data: (resignation) {
                  if (resignation == null) {
                    return Padding(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: PremiumCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.assignment_outlined,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "No active resignation",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Create a resignation request only when you are ready to start the approval workflow.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: openForm,
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text("Apply Resignation"),
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
    return SingleChildScrollView(
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
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.assignment_return_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Apply Resignation",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "This request will move to Manager, then HOD, then HR for final approval.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Reason and remarks become part of the official approval record.",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Request Details",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: "Reason / remarks *",
                    alignLabelWithHint: true,
                    hintText:
                        "Required — this text is part of the approval record",
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Last Working Date",
                    hintText: "Select expected last working day",
                    suffixIcon: const Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onTap: pickDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text("Submit Request"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(ResignationModel resignation) {
    final status = resignation.status;
    bool canApplyAgain = status == "Rejected" || status == "Withdrawn";

    Color badgeColor() {
      switch (status) {
        case "Pending":
          return Colors.orange;
        case "Manager Approved":
        case "HOD Approved":
          return Colors.indigo;
        case "Rejected":
          return Colors.red;
        case "HR Approved":
          return Colors.green;
        default:
          return Theme.of(context).colorScheme.primary;
      }
    }

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumFeatureHeader(
            icon: Icons.assignment_return_outlined,
            title: "Resignation Workflow",
            subtitle: "Employee -> Manager -> HOD -> HR",
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WorkflowStepper(status: status),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: badgeColor(),
                        ),
                        label: Text(status),
                        side: BorderSide(color: badgeColor()),
                      ),
                      if (resignation.lastWorkingDate != null)
                        Chip(
                          label: Text("LWD: ${resignation.lastWorkingDate}"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Reason / remarks",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    resignation.reason,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timelineText(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_canWithdrawResignation(status))
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => withdraw(resignation.id),
                icon: const Icon(Icons.undo_rounded),
                label: const Text("Withdraw Request"),
              ),
            ),
          if (_canWithdrawResignation(status)) const SizedBox(height: 10),
          if (canApplyAgain)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: openForm,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Apply Again"),
              ),
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
          color: Theme.of(
            context,
          ).colorScheme.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              status == "Rejected" ? Icons.close_rounded : Icons.undo_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == "Rejected"
                    ? "Workflow closed as rejected"
                    : "Workflow closed as withdrawn",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
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
                      color: done
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.circle_outlined,
                      size: 15,
                      color: done
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: index < step
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
