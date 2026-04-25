import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ REQUIRED
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';

class PayslipPdfService {
  static Future<void> generate(BuildContext context, Payslip payslip) async {
    final font = await pw.Font.ttf(
      await rootBundle.load("assets/fonts/Roboto-Regular.ttf"),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    /// 🔥 LOAD LOGO (FIXED)
    pw.MemoryImage? logoImage;

    try {
      if (payslip.company.logo != null) {
        final url = "${ApiConstants.companyLogoBaseUrl}${payslip.company.logo}";

        final response = await HttpClient().getUrl(Uri.parse(url));
        final result = await response.close();

        final bytes = await consolidateHttpClientResponseBytes(result);

        logoImage = pw.MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint("Logo load failed: $e");
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              /// 🏢 HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Image(logoImage, height: 50, width: 50),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            payslip.company.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          pw.Text(
                            payslip.company.address,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "PAYSLIP",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      pw.Text(
                        "${_getMonthName(payslip.month)} ${payslip.year}",
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              /// 👤 EMPLOYEE DETAILS
              _pdfBox([
                _pdfRow("Employee", payslip.employee.name),
                _pdfRow("Department", payslip.employee.department),
                _pdfRow("Email", payslip.employee.email),
              ]),

              pw.SizedBox(height: 16),

              /// 📊 COMBINED TABLE (HRMS STYLE)
              _combinedTable(payslip),

              pw.SizedBox(height: 16),

              /// 💰 NET SALARY HIGHLIGHT
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  border: pw.Border.all(),
                ),
                child: _pdfRow(
                  "NET SALARY",
                  "₹${payslip.netSalary.toStringAsFixed(2)}",
                  isBold: true,
                ),
              ),

              pw.Spacer(),

              /// 🧾 FOOTER
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "This is a system generated payslip",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 30),
                      pw.Container(width: 100, child: pw.Divider()),
                      pw.Text(
                        "Authorized Signatory",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    /// 💾 SAVE FILE
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      "${dir.path}/payslip_${payslip.month}_${payslip.year}.pdf",
    );

    await file.writeAsBytes(await pdf.save());

    /// 📂 OPEN FILE
    await OpenFilex.open(file.path);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Payslip downloaded")));
  }
}

pw.Widget _pdfBox(List<pw.Widget> children) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
    child: pw.Column(children: children),
  );
}

pw.Widget _combinedTable(Payslip payslip) {
  final earnings = payslip.earnings.entries.toList();
  final deductions = payslip.deductions.entries.toList();

  final max = earnings.length > deductions.length
      ? earnings.length
      : deductions.length;

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _pdfCell("Earnings", isHeader: true),
          _pdfCell("Amount", isHeader: true),
          _pdfCell("Deductions", isHeader: true),
          _pdfCell("Amount", isHeader: true),
        ],
      ),
      ...List.generate(max, (i) {
        final e = i < earnings.length ? earnings[i] : null;
        final d = i < deductions.length ? deductions[i] : null;

        return pw.TableRow(
          children: [
            _pdfCell(e != null ? _formatKey(e.key) : ""),
            _pdfCell(
              e != null ? "₹${_toDouble(e.value).toStringAsFixed(2)}" : "",
            ),
            _pdfCell(d != null ? _formatKey(d.key) : ""),
            _pdfCell(
              d != null ? "₹${_toDouble(d.value).toStringAsFixed(2)}" : "",
            ),
          ],
        );
      }),
    ],
  );
}

pw.Widget _pdfRow(String label, String value, {bool isBold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfCell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: 10,
      ),
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
