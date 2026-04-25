import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/resignation/data/models/resignation_model.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';

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
      _show("Reason is required");
      return;
    }

    _isSubmitting = true;

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
        _show("Resignation submitted ✅");

        reasonController.clear();
        dateController.clear();

        Navigator.pop(context); // close bottom sheet
        ref.invalidate(myResignationProvider);
      } else {
        _show("Error: ${state.error}");
      }
    } finally {
      _isSubmitting = false;
    }
  }

  /// 🔁 WITHDRAW
  Future<void> withdraw(String id) async {
    await ref.read(resignationActionProvider.notifier).withdraw(id);
    _show("Resignation withdrawn");
    ref.invalidate(myResignationProvider);
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 📦 OPEN FORM
  void openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _buildForm(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resignationAsync = ref.watch(myResignationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("My Resignation")),

      body: resignationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text("Error: $e")),

        data: (resignation) {
          if (resignation == null) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.12),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Create a resignation request only when you are ready to start the approval workflow.",
                        textAlign: TextAlign.center,
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
          const Text(
            "Apply Resignation",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "This request will move to Manager, then HOD, then HR for final approval.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "Reason *",
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Last Working Date",
              suffixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            onTap: pickDate,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submit,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Resignation Workflow",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Employee → Manager → HOD → HR",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          if (status == "Pending")
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => withdraw(resignation.id),
                icon: const Icon(Icons.undo_rounded),
                label: const Text("Withdraw Request"),
              ),
            ),
          if (status == "Pending") const SizedBox(height: 10),
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
