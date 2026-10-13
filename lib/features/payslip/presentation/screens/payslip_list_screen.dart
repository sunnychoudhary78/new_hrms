import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/core/services/pdf_service.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:lms/features/payslip/presentation/screens/payslip_details_screen.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: "My Payslips"),
      body: payslipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PremiumCard(
            child: Text(
              "Unable to load payslips.\n$e",
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
        data: (payslips) {
          if (payslips.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: PremiumEmptyState(
                icon: Icons.receipt_long_outlined,
                title: "No payslips available",
                subtitle: "Published salary slips will appear here.",
              ),
            );
          }

          /// FILTER
          final filtered = selectedMonth == null
              ? payslips
              : payslips.where((p) => p.month == selectedMonth).toList();

          return Column(
            children: [
              const PremiumFeatureHeader(
                icon: Icons.account_balance_wallet_outlined,
                title: "My Payslips",
                subtitle:
                    "Browse monthly salary slips and view or download PDF.",
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
                      ? ListView(
                          physics: isIOS
                              ? const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                )
                              : const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            PremiumEmptyState(
                              icon: Icons.filter_alt_off_outlined,
                              title: "No data for selected month",
                              subtitle: "Try another month or choose All.",
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: isIOS
                              ? const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                )
                              : const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
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
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppFilterChip(
        label: label,
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _PayslipCard extends ConsumerWidget {
  final Payslip payslip;
  final bool isIOS;

  const _PayslipCard({required this.payslip, required this.isIOS});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublished = payslip.status.toLowerCase() == 'published';
    final canDownload = payslip.isDownloadable;
    final statusColor = isPublished
        ? AppColors.success
        : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumCard(
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
                    color: AppColors.title,
                  ),
                ),
                PremiumStatusPill(
                  label: payslip.status.toUpperCase(),
                  color: statusColor,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              "₹${payslip.netSalary.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              "Net Salary",
              style: TextStyle(color: AppColors.muted),
            ),

            if (payslip.hasOvertimePay) ...[
              const SizedBox(height: 8),
              Text(
                "OT: ₹${payslip.overtimePay.toStringAsFixed(2)} (${payslip.overtimeHours.toStringAsFixed(2)} hrs)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning.withValues(alpha: 0.95),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton(
                  onPressed: canDownload
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PayslipDetailScreen(payslip: payslip),
                            ),
                          );
                        }
                      : null,
                  child: const Text("View"),
                ),

                TextButton(
                  onPressed: canDownload
                      ? () async {
                          final dio = ref.read(dioClientProvider).dio;
                          await PayslipPdfService.download(
                            context,
                            dio,
                            payslip,
                          );
                        }
                      : null,
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
