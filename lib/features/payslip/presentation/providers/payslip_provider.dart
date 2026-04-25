import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:lms/features/payslip/data/repository/payslip_repository.dart';

final payslipApiServiceProvider = Provider((ref) {
  final api = ref.read(apiServiceProvider);
  return PayslipApiService(api);
});

final payslipsProvider = FutureProvider<List<Payslip>>((ref) async {
  final api = ref.read(payslipApiServiceProvider);
  return api.getMyPayslips();
});
