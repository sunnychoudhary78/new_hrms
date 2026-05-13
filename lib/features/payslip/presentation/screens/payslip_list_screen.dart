import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/services/pdf_service.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:lms/features/payslip/presentation/screens/payslip_details_screen.dart';
import 'package:lms/shared/widgets/app_bar.dart';

import '../providers/payslip_provider.dart';

class PayslipListScreen extends ConsumerStatefulWidget {
  const PayslipListScreen({super.key});

  @override
  ConsumerState<PayslipListScreen> createState() => _PayslipListScreenState();
}

class _PayslipListScreenState extends ConsumerState<PayslipListScreen> {
  int? selectedMonth;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(payslipsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final payslipsAsync = ref.watch(payslipsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: "My Payslips"),
      body: payslipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
            ),
            child: Text(
              "Unable to load payslips.\n$e",
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),
        data: (payslips) {
          if (payslips.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
                  color: scheme.surfaceContainerLow,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 44),
                    SizedBox(height: 10),
                    Text("No payslips available"),
                  ],
                ),
              ),
            );
          }

          /// FILTER
          final filtered = selectedMonth == null
              ? payslips
              : payslips.where((p) => p.month == selectedMonth).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isIOS ? 14 : 18),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Text(
                  "Browse monthly salary slips and open details or download PDF.",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              _MonthFilter(
                payslips: payslips,
                selectedMonth: selectedMonth,
                isIOS: isIOS,
                onChanged: (m) => setState(() => selectedMonth = m),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(payslipsProvider);
                  },
                  child: filtered.isEmpty
                      ? const Center(child: Text("No data for selected month"))
                      : ListView.builder(
                          physics: isIOS
                              ? const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                )
                              : const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _PayslipCard(
                            payslip: filtered[i],
                            isIOS: isIOS,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthFilter extends StatelessWidget {
  final List<Payslip> payslips;
  final int? selectedMonth;
  final bool isIOS;
  final Function(int?) onChanged;

  const _MonthFilter({
    required this.payslips,
    required this.selectedMonth,
    required this.isIOS,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final months = payslips.map((e) => e.month).toSet().toList()..sort();

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip("All", selectedMonth == null, () => onChanged(null)),
          ...months.map(
            (m) =>
                _chip(_getMonthName(m), selectedMonth == m, () => onChanged(m)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final Payslip payslip;
  final bool isIOS;

  const _PayslipCard({required this.payslip, required this.isIOS});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPublished = payslip.status.toLowerCase() == 'published';
    final cardRadius = BorderRadius.circular(isIOS ? 12 : 16);
    final pillRadius = BorderRadius.circular(isIOS ? 14 : 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_getMonthName(payslip.month)} ${payslip.year}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? Colors.green.withValues(alpha: 0.14)
                        : Colors.orange.withValues(alpha: 0.14),
                    borderRadius: pillRadius,
                  ),
                  child: Text(
                    payslip.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isPublished ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              "₹${payslip.netSalary.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "Net Salary",
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayslipDetailScreen(payslip: payslip),
                      ),
                    );
                  },
                  child: const Text("View"),
                ),

                TextButton(
                  onPressed: () async {
                    await PayslipPdfService.generate(context, payslip);
                  },
                  child: const Text("Download"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _getMonthName(int month) {
  const months = [
    "",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return (month >= 1 && month <= 12) ? months[month] : "Unknown";
}
