import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class MyExpensesScreen extends ConsumerStatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  ConsumerState<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends ConsumerState<MyExpensesScreen> {
  String selectedTab = "All";

  final List<String> tabs = ["All", "Draft", "Pending", "Approved", "Rejected"];

  Future<void> _refreshMyExpenses() async {
    ref.invalidate(myExpensesProvider);
    await ref.read(myExpensesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(myExpensesProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: "My Expenses"),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () async {
          await Navigator.pushNamed(context, "/expenses/create");
          ref.invalidate(myExpensesProvider);
        },
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          _buildHeader(expensesAsync),
          SizedBox(
            height: 56,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              scrollDirection: Axis.horizontal,
              physics: isIOS
                  ? const BouncingScrollPhysics()
                  : const ClampingScrollPhysics(),
              itemCount: tabs.length,
              itemBuilder: (_, i) {
                final tab = tabs[i];
                final isSelected = tab == selectedTab;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppFilterChip(
                    label: tab,
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedTab = tab),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshMyExpenses,
              child: expensesAsync.when(
                loading: () => ListView(
                  physics: scrollPhysics,
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (e, _) => ListView(
                  physics: scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [Text("Error: $e", textAlign: TextAlign.center)],
                ),
                data: (expenses) {
                  final filtered = expenses.where((e) {
                    if (selectedTab == "All") return true;
                    if (selectedTab == "Draft") {
                      return e.status == "Draft";
                    }
                    if (selectedTab == "Approved") {
                      return [
                        "Manager Approved",
                        "HOD Approved",
                        "Processed",
                      ].contains(e.status);
                    }

                    return e.status.toLowerCase() == selectedTab.toLowerCase();
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: scrollPhysics,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      children: const [
                        SizedBox(height: 80),
                        PremiumEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: "No claims found",
                          subtitle:
                              "Try another status or create a new expense claim.",
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: scrollPhysics,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final exp = filtered[i];

                      return _buildExpenseTile(exp);
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

  Widget _buildHeader(AsyncValue<List<ExpenseClaim>> expensesAsync) {
    return expensesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final total = data.fold<double>(
          0,
          (sum, item) => sum + item.totalAmount,
        );
        return PremiumFeatureHeader(
          icon: Icons.receipt_long,
          title: "My Expense Claims",
          subtitle:
              "${data.length} claim(s) submitted across drafts, approvals and payments.",
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                "₹${total.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(ExpenseClaim exp) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final tileRadius = AppRadius.lg;
    return InkWell(
      borderRadius: BorderRadius.circular(tileRadius),
      onTap: () async {
        await Navigator.pushNamed(context, "/expenses/detail", arguments: exp);
        ref.invalidate(myExpensesProvider);
      },
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: AppColors.iconBg,
              ),
              child: Icon(
                Icons.payments_outlined,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _statusChip(exp.status),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (exp.status == "Draft")
              IconButton(
                tooltip: "Edit draft",
                icon: const Icon(Icons.edit_outlined),
                style: IconButton.styleFrom(
                  splashFactory: isIOS
                      ? NoSplash.splashFactory
                      : InkSplash.splashFactory,
                ),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    "/expenses/create",
                    arguments: exp,
                  );
                  ref.invalidate(myExpensesProvider);
                },
              ),
            Text(
              "₹${exp.totalAmount.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return PremiumStatusPill(
      label: status,
      color: AppColors.statusColor(status),
    );
  }
}
