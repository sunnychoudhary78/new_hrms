import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/network_providers.dart';

import '../../data/leave_details_api_service.dart';

import '../../data/models/leave_details_model.dart';

/// API provider
final leaveDetailsApiProvider = Provider<LeaveDetailsApiService>((ref) {
  final api = ref.read(apiServiceProvider);

  return LeaveDetailsApiService(api);
});

/// Leave Details Provider (FAMILY provider)
final leaveDetailsProvider = FutureProvider.family<LeaveDetails, String>((
  ref,
  leaveId,
) async {
  final api = ref.read(leaveDetailsApiProvider);

  final json = await api.fetchLeaveDetails(leaveId);

  return LeaveDetails.fromJson(json);
});
