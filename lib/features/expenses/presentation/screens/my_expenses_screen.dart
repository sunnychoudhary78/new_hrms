import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final expensesAsync = ref.watch(myExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Expenses"),
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, "/expenses/create");
          ref.invalidate(myExpensesProvider);
        },
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          _buildHeader(scheme, expensesAsync),
          SizedBox(
            height: 56,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (_, i) {
                final tab = tabs[i];
                final isSelected = tab == selectedTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedTab = tab),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text("Error: $e", textAlign: TextAlign.center),
                  ],
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.25,
                        ),
                        Center(
                          child: Text(
                            "No claims found",
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
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

  Widget _buildHeader(
    ColorScheme scheme,
    AsyncValue<List<ExpenseClaim>> expensesAsync,
  ) {
    return expensesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final total = data.fold<double>(
          0,
          (sum, item) => sum + item.totalAmount,
        );
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer,
                scheme.secondaryContainer,
              ],
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primary,
                child: Icon(Icons.receipt_long, color: scheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Claims",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${data.length}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "₹${total.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(ExpenseClaim exp) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.pushNamed(context, "/expenses/detail", arguments: exp);
        ref.invalidate(myExpensesProvider);
      },
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
              child: Icon(Icons.payments_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _statusChip(exp.status),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "₹${exp.totalAmount.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;

    switch (status) {
      case "Draft":
        color = Colors.grey;
        break;
      case "Pending":
        color = Colors.orange;
        break;
      case "Rejected":
        color = Colors.red;
        break;
      case "Manager Approved":
      case "HOD Approved":
      case "Processed":
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }

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
