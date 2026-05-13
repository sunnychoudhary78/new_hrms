import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/services/pdf_service.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class PayslipDetailScreen extends StatelessWidget {
  final Payslip payslip;

  const PayslipDetailScreen({super.key, required this.payslip});

  @override
  Widget build(BuildContext context) {
    final logoUrl = payslip.company.logo != null
        ? "${ApiConstants.companyLogoBaseUrl}${payslip.company.logo}"
        : null;

    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final outerRadius = BorderRadius.circular(isIOS ? 12 : 16);
    final innerRadius = BorderRadius.circular(isIOS ? 10 : 12);
    final logoRadius = BorderRadius.circular(isIOS ? 6 : 8);

    return Scaffold(
      appBar: const AppAppBar(title: "Payslip"),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: outerRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                _HeaderSection(
                  logoUrl: logoUrl,
                  payslip: payslip,
                  logoRadius: logoRadius,
                ),

                const Divider(height: 24),

                /// EMPLOYEE
                _InfoSection(payslip: payslip),

                const Divider(height: 24),

                /// SALARY SUMMARY
                _SalarySummary(
                  payslip: payslip,
                  borderRadius: innerRadius,
                  fillColor: scheme.surfaceContainerHighest,
                ),

                const Divider(height: 24),

                /// BREAKDOWN
                _BreakdownSection(
                  payslip: payslip,
                  borderRadius: innerRadius,
                  borderColor: scheme.outlineVariant,
                ),

                const SizedBox(height: 24),

                /// DOWNLOAD
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text("Download Payslip"),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Generating payslip...")),
                      );

                      await PayslipPdfService.generate(context, payslip);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String? logoUrl;
  final Payslip payslip;
  final BorderRadius logoRadius;

  const _HeaderSection({
    this.logoUrl,
    required this.payslip,
    required this.logoRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (logoUrl != null)
          ClipRRect(
            borderRadius: logoRadius,
            child: Image.network(logoUrl!, height: 50, width: 50),
          )
        else
          const Icon(Icons.business, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payslip.company.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                payslip.company.address,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Payslip payslip;

  const _InfoSection({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row("Employee", payslip.employee.name),
        _row("Department", payslip.employee.department),
        _row("Email", payslip.employee.email),

        const SizedBox(height: 8),

        _row("Month", _getMonthName(payslip.month)),
        _row("Year", payslip.year.toString()),
        _row("Payable Days", payslip.payableDays.toString()),
        _row("Total Days", payslip.totalDays.toString()),
        _row("Status", payslip.status),
      ],
    );
  }
}

class _SalarySummary extends StatelessWidget {
  final Payslip payslip;
  final BorderRadius borderRadius;
  final Color fillColor;

  const _SalarySummary({
    required this.payslip,
    required this.borderRadius,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: fillColor,
      ),
      child: Column(
        children: [
          _amountRow("Gross Salary", payslip.grossSalary),
          _amountRow("Total Deductions", payslip.totalDeductions),

          const Divider(),

          /// 🔥 HIGHLIGHT NET SALARY
          _amountRow("Net Salary", payslip.netSalary, isBold: true),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final Payslip payslip;
  final BorderRadius borderRadius;
  final Color borderColor;

  const _BreakdownSection({
    required this.payslip,
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// EARNINGS
        _sectionCard(
          title: "Earnings",
          borderRadius: borderRadius,
          borderColor: borderColor,
          children: payslip.earnings.entries
              .map((e) => _amountRow(_formatKey(e.key), _toDouble(e.value)))
              .toList(),
        ),

        const SizedBox(height: 12),

        /// DEDUCTIONS
        _sectionCard(
          title: "Deductions",
          borderRadius: borderRadius,
          borderColor: borderColor,
          children: payslip.deductions.entries
              .map((e) => _amountRow(_formatKey(e.key), _toDouble(e.value)))
              .toList(),
        ),
      ],
    );
  }
}

Widget _sectionCard({
  required String title,
  required BorderRadius borderRadius,
  required Color borderColor,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),

        ...children,
      ],
    ),
  );
}

/// ───────────────── HELPERS ─────────────────

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

Widget _amountRow(String label, double value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

String _getMonthName(int month) {
  const months = [
    "",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  return (month >= 1 && month <= 12) ? months[month] : "Unknown";
}

String _formatKey(String key) {
  return key.replaceAll("_", " ").toUpperCase();
}

double _toDouble(dynamic value) {
  return double.tryParse(value.toString()) ?? 0;
}
