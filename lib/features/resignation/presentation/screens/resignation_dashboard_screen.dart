import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/resignation/presentation/providers/resignation_providers.dart';

class ResignationDashboardScreen extends ConsumerStatefulWidget {
  const ResignationDashboardScreen({super.key});

  @override
  ConsumerState<ResignationDashboardScreen> createState() =>
      _ResignationDashboardScreenState();
}

class _ResignationDashboardScreenState
    extends ConsumerState<ResignationDashboardScreen> {
  String selectedTab = "Pending Queue";

  final tabs = ["Pending Queue", "Final Approved", "Rejected"];

  bool matchesTab(String status) {
    if (selectedTab == "Pending Queue") {
      return status == "Pending" ||
          status == "Manager Approved" ||
          status == "HOD Approved";
    }

    if (selectedTab == "Final Approved") {
      return status == "HR Approved";
    }

    if (selectedTab == "Rejected") {
      return status == "Rejected";
    }

    return true;
  }

  Future<void> showActionDialog({
    required String id,
    required bool isApprove,
  }) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isApprove ? "Approve Resignation" : "Reject Resignation"),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: "Remarks ${isApprove ? '(optional)' : '*'}",
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final remarks = controller.text.trim();

              if (!isApprove && remarks.isEmpty) {
                _show("Remarks required");
                return;
              }

              Navigator.pop(context);

              if (isApprove) {
                await ref
                    .read(resignationActionProvider.notifier)
                    .approve(id, remarks);
              } else {
                await ref
                    .read(resignationActionProvider.notifier)
                    .reject(id, remarks);
              }

              final state = ref.read(resignationActionProvider);

              if (!state.hasError) {
                _show(isApprove ? "Request approved" : "Request rejected");
              } else {
                _show("Error: ${state.error}");
              }
            },
            child: Text(isApprove ? "Approve" : "Reject"),
          ),
        ],
      ),
    );
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final resignationsAsync = ref.watch(resignationDashboardProvider);
    final role = ref.watch(resignationRoleProvider);
    final roleTitle = switch (role) {
      ResignationRole.manager => "Manager",
      ResignationRole.hod => "HOD",
      ResignationRole.hr => "HR",
      ResignationRole.employee => "Employee",
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Resignation Dashboard")),

      body: Column(
        children: [
          _WorkflowHeader(roleTitle: roleTitle),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (_, i) {
                final tab = tabs[i];
                final isSelected = tab == selectedTab;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTab = tab;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: resignationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),

              error: (e, _) => Center(child: Text("Error: $e")),

              data: (list) {
                if (role == ResignationRole.employee) {
                  return const Center(
                    child: Text("No dashboard access for employee role"),
                  );
                }

                final filtered = list
                    .where((e) => matchesTab(e.status))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No requests in this section"),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final canTakeAction = _canTakeAction(
                      role: role,
                      status: r.status,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
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
                                      onPressed: () => showActionDialog(
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
                                      onPressed: () => showActionDialog(
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
        ],
      ),
    );
  }

  bool _canTakeAction({required ResignationRole role, required String status}) {
    switch (role) {
      case ResignationRole.manager:
        return status == "Pending";
      case ResignationRole.hod:
        return status == "Manager Approved";
      case ResignationRole.hr:
        return status == "HOD Approved";
      case ResignationRole.employee:
        return false;
    }
  }

  String _stageText(String status) {
    switch (status) {
      case "Pending":
        return "Waiting for Manager";
      case "Manager Approved":
        return "Waiting for HOD";
      case "HOD Approved":
        return "Waiting for HR";
      case "HR Approved":
        return "Completed";
      case "Rejected":
        return "Closed";
      default:
        return status;
    }
  }
}

class _WorkflowHeader extends StatelessWidget {
  final String roleTitle;

  const _WorkflowHeader({required this.roleTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$roleTitle Approval Queue",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Workflow: Employee → Manager → HOD → HR",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      "Pending" => Colors.orange,
      "Manager Approved" || "HOD Approved" => Colors.indigo,
      "HR Approved" => Colors.green,
      "Rejected" => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
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
