import 'package:lms/core/network/api_endpoints.dart';
import '../../../../core/network/api_service.dart';
import '../models/payslip_model.dart';

class PayslipApiService {
  final ApiService api;

  PayslipApiService(this.api);

  /// ───────────────── PAYSLIPS ─────────────────

  Future<List<Payslip>> getMyPayslips() async {
    final response = await api.get(ApiEndpoints.myPayslips);

    // Your API returns List directly
    final List list = response;

    return list.map((e) => Payslip.fromJson(e)).toList();
  }
}
