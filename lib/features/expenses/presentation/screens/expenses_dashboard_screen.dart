import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpensesDashboardScreen extends ConsumerStatefulWidget {
  const ExpensesDashboardScreen({super.key});

  @override
  ConsumerState<ExpensesDashboardScreen> createState() =>
      _ExpensesDashboardScreenState();
}

class _ExpensesDashboardScreenState
    extends ConsumerState<ExpensesDashboardScreen> {
  Future<void> _refreshDashboard() async {
    ref.invalidate(expenseDashboardProvider);
    await ref.read(expenseDashboardProvider.future);
  }

  Widget _statusFilterChips(ExpenseDashboardRole role, ColorScheme scheme) {
    final choices = expenseDashboardStatusChoices(role);
    if (choices.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(expenseDashboardStatusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: defaultTargetPlatform == TargetPlatform.iOS
              ? const BouncingScrollPhysics()
              : const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (final s in choices) ...[
                FilterChip(
                  label: Text(s),
                  selected: selected == s,
                  onSelected: (_) {
                    ref
                        .read(expenseDashboardStatusFilterProvider.notifier)
                        .setFilter(s);
                  },
                  showCheckmark: false,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expensesAsync = ref.watch(expenseDashboardProvider);
    final role = ref.watch(expenseDashboardRoleProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();

    final roleTitle = switch (role) {
      ExpenseDashboardRole.manager => "Manager",
      ExpenseDashboardRole.hod => "HOD",
      ExpenseDashboardRole.accounts => "Accounts",
      ExpenseDashboardRole.employee => "Employee",
    };

    return Scaffold(
      appBar: const AppAppBar(title: "Expenses Dashboard"),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: expensesAsync.when(
          loading: () => ListView(
            physics: scrollPhysics,
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
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
                physics: scrollPhysics,
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No dashboard access for employee role")),
                ],
              );
            }

            final statusFilter = ref.watch(
              expenseDashboardStatusFilterProvider,
            );
            final claimCount = expenses.length;
            final totalAmount = expenses.fold<double>(
              0,
              (sum, e) => sum + e.totalAmount,
            );

            return ListView(
              physics: scrollPhysics,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                PremiumFeatureHeader(
                  icon: Icons.analytics_outlined,
                  title: "$roleTitle Expense Queue",
                  subtitle:
                      "Review, approve and process claims from your action queue. Change status below to audit other stages.",
                ),
                const SizedBox(height: 14),
                _statusFilterChips(role, scheme),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: "Claims (this filter)",
                        value: claimCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: "Total amount",
                        value: "₹${totalAmount.toStringAsFixed(0)}",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Showing: $statusFilter',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                if (expenses.isEmpty)
                  PremiumEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No expense claims for "$statusFilter"',
                    subtitle: "Try another status or pull down to refresh.",
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final tileRadius = isIOS ? 14.0 : 16.0;

    return InkWell(
      borderRadius: BorderRadius.circular(tileRadius),
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
        child: PremiumCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
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

    return PremiumStatusPill(label: status, color: color);
  }
}
