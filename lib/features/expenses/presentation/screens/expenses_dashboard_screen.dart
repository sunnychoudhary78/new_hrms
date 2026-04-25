import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpensesDashboardScreen extends ConsumerStatefulWidget {
  const ExpensesDashboardScreen({super.key});

  @override
  ConsumerState<ExpensesDashboardScreen> createState() =>
      _ExpensesDashboardScreenState();
}

class _ExpensesDashboardScreenState extends ConsumerState<ExpensesDashboardScreen> {
  Future<void> _refreshDashboard() async {
    ref.invalidate(expenseDashboardProvider);
    await ref.read(expenseDashboardProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expensesAsync = ref.watch(expenseDashboardProvider);
    final role = ref.watch(expenseDashboardRoleProvider);

    final roleTitle = switch (role) {
      ExpenseDashboardRole.manager => "Manager",
      ExpenseDashboardRole.hod => "HOD",
      ExpenseDashboardRole.accounts => "Accounts",
      ExpenseDashboardRole.employee => "Employee",
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses Dashboard"),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: expensesAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "Unable to load expenses dashboard.\n$e",
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
          data: (expenses) {
            if (role == ExpenseDashboardRole.employee) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No dashboard access for employee role")),
                ],
              );
            }

            final pendingCount = expenses.length;
            final pendingAmount = expenses.fold<double>(
              0,
              (sum, e) => sum + e.totalAmount,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [scheme.primaryContainer, scheme.secondaryContainer],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.analytics_outlined,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$roleTitle queue for pending expense claims.",
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: "Pending",
                        value: pendingCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: "Pending Amount",
                        value: "₹${pendingAmount.toStringAsFixed(0)}",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (expenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surfaceContainerLow,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 44,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "No pending expense requests.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Pull down to refresh and check again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  ...expenses.map(_buildExpenseTile),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpenseTile(ExpenseClaim expense) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.pushNamed(
          context,
          "/expenses/detail",
          arguments: expense,
        );
        ref.invalidate(expenseDashboardProvider);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.primaryContainer,
                ),
                child: Icon(Icons.receipt_long_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expense.employeeName?.trim().isNotEmpty == true
                          ? expense.employeeName!
                          : "Employee",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(status: expense.status),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "₹${expense.totalAmount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              fontSize: 18,
            ),
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
    final color = switch (status.toLowerCase()) {
      "pending" => Colors.orange,
      "draft" => Colors.grey,
      "rejected" => Colors.red,
      "manager approved" || "hod approved" || "processed" => Colors.green,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
