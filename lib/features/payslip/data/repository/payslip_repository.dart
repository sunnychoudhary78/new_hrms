import 'package:lms/core/network/api_endpoints.dart';
import '../../../../core/network/api_service.dart';
import '../models/payslip_model.dart';

class PayslipApiService {
  final ApiService api;

  PayslipApiService(this.api);

  /// ───────────────── PAYSLIPS ─────────────────

  Future<List<Payslip>> getMyPayslips() async {
    const pageSize = 100;
    final payslips = <Payslip>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await api.get(
        ApiEndpoints.myPayslips,
        queryParams: {"page": page, "limit": pageSize},
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => Payslip.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final data = response is Map ? response['data'] : null;
      if (data is List) {
        payslips.addAll(
          data
              .whereType<Map>()
              .map((e) => Payslip.fromJson(Map<String, dynamic>.from(e))),
        );
      }

      final meta = response is Map ? response['meta'] : null;
      if (meta is Map && meta['totalPages'] != null) {
        totalPages = int.tryParse(meta['totalPages'].toString()) ?? totalPages;
      } else {
        break;
      }

      page++;
    } while (page <= totalPages);

    return payslips;
  }
}
