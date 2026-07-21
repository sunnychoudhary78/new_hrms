import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PayslipPdfException implements Exception {
  final String message;

  const PayslipPdfException(this.message);

  @override
  String toString() => message;
}

class PayslipPdfService {
  static Future<Uint8List> fetchPdfBytes(Dio dio, Payslip payslip) async {
    if (!payslip.isDownloadable) {
      throw const PayslipPdfException(
        'Payslip is not available for download yet',
      );
    }

    try {
      final response = await dio.get(
        ApiEndpoints.myPayslipDownload(payslip.id),
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status == 200,
        ),
      );

      final bytes = _toBytes(response.data);
      if (bytes == null || bytes.isEmpty || !_looksLikePdf(bytes)) {
        throw const PayslipPdfException('Invalid PDF response from server');
      }

      return bytes;
    } on DioException catch (e) {
      throw PayslipPdfException(_errorMessage(e));
    }
  }

  static Future<void> download(
    BuildContext context,
    Dio dio,
    Payslip payslip,
  ) async {
    if (!payslip.isDownloadable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payslip is not available for download yet'),
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading payslip...')),
      );

      final bytes = await fetchPdfBytes(dio, payslip);

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/payslip_${payslip.month}_${payslip.year}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payslip downloaded')),
        );
      }
    } on PayslipPdfException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download payslip: $e')),
        );
      }
    }
  }

  static Uint8List? _toBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  static bool _looksLikePdf(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static String _errorMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 403) return 'Payslip is not available for download yet';
    if (status == 404) return 'Payslip not found';
    return 'Could not download payslip';
  }
}
