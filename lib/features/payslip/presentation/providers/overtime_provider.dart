import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';

import '../../data/overtime_api_service.dart';

final overtimeApiServiceProvider = Provider<OvertimeApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return OvertimeApiService(api);
});
