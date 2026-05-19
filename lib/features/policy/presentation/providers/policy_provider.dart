import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/policy/data/models/policy_model.dart';
import 'package:lms/features/policy/data/policy_api_service.dart';

final policyApiServiceProvider = Provider<PolicyApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return PolicyApiService(api);
});

final policiesProvider = FutureProvider.autoDispose<List<PolicyModel>>((
  ref,
) async {
  final api = ref.read(policyApiServiceProvider);
  return api.getPolicies();
});
