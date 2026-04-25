import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/kra/data/kra_api_service.dart';
import 'package:lms/features/kra/data/kra_repository.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';

enum KraReviewMode {
  self('self', 'My Review'),
  team('team', 'Team Reviews'),
  department('department', 'Department'),
  all('all', 'All Reviews');

  final String apiValue;
  final String label;

  const KraReviewMode(this.apiValue, this.label);
}

final kraApiServiceProvider = Provider<KraApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return KraApiService(api);
});

final kraRepositoryProvider = Provider<KraRepository>((ref) {
  final api = ref.read(kraApiServiceProvider);
  return KraRepository(api);
});

final canManageKraProvider = Provider<bool>((ref) {
  final permissions = ref.watch(authProvider).permissions;
  return permissions.contains('kra.manage');
});

final hasAnyKraPermissionProvider = Provider<bool>((ref) {
  final permissions = ref.watch(authProvider).permissions;
  return permissions.any((permission) => permission.startsWith('kra.'));
});

final kraVisibleReviewModesProvider = Provider<List<KraReviewMode>>((ref) {
  final permissions = ref.watch(authProvider).permissions;
  return [
    if (permissions.contains('kra.myrating')) KraReviewMode.self,
    if (permissions.contains('kra.teamrating')) KraReviewMode.team,
    if (permissions.contains('kra.department')) KraReviewMode.department,
    if (permissions.contains('kra.allrating')) KraReviewMode.all,
  ];
});

final myKrasProvider = FutureProvider<List<KraModel>>((ref) async {
  final profile = ref.watch(authProvider.select((s) => s.profile));
  final employeeId = profile?.userId ?? profile?.id;
  final repo = ref.read(kraRepositoryProvider);
  return repo.listKras(employeeId: employeeId);
});

final managedKrasProvider = FutureProvider<List<KraModel>>((ref) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final repo = ref.read(kraRepositoryProvider);
  return repo.listKras();
});

final kraTeamMembersProvider = FutureProvider<List<KraPerson>>((ref) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final repo = ref.read(kraRepositoryProvider);
  return repo.getTeamMembers();
});

final kraCyclesProvider = FutureProvider<List<KraCycle>>((ref) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final repo = ref.read(kraRepositoryProvider);
  return repo.listCycles();
});

final kraActiveCycleProvider = FutureProvider<KraCycle?>((ref) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final repo = ref.read(kraRepositoryProvider);
  return repo.getActiveCycle();
});

final kraEvaluationsProvider =
    FutureProvider.family<List<KraEvaluation>, KraReviewMode>((
      ref,
      mode,
    ) async {
      ref.watch(authProvider.select((s) => s.profile?.userId));
      final repo = ref.read(kraRepositoryProvider);
      return repo.listEvaluations(mode: mode.apiValue);
    });

final kraActionProvider = NotifierProvider<KraActionNotifier, AsyncValue<void>>(
  KraActionNotifier.new,
);

class KraActionNotifier extends Notifier<AsyncValue<void>> {
  late final KraRepository repo;

  @override
  AsyncValue<void> build() {
    repo = ref.read(kraRepositoryProvider);
    return const AsyncValue.data(null);
  }

  Future<void> saveKra({
    String? id,
    required String name,
    required String description,
    String? departmentId,
    String? employeeId,
    required List<KpiModel> kpis,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repo.saveKra(
        id: id,
        name: name,
        description: description,
        departmentId: departmentId,
        employeeId: employeeId,
        kpis: kpis,
      );
      _invalidateKraData();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteKra(String id) async {
    state = const AsyncValue.loading();
    try {
      await repo.deleteKra(id);
      _invalidateKraData();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> initiateCycle({required int month, required int year}) async {
    state = const AsyncValue.loading();
    try {
      await repo.initiateCycle(month: month, year: year);
      ref.invalidate(kraCyclesProvider);
      ref.invalidate(kraActiveCycleProvider);
      for (final mode in KraReviewMode.values) {
        ref.invalidate(kraEvaluationsProvider(mode));
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitRating({
    required String evaluationId,
    required KraReviewMode mode,
    required List<Map<String, dynamic>> ratings,
    Map<String, String> documentPathsByKpi = const {},
  }) async {
    state = const AsyncValue.loading();
    try {
      await repo.submitRating(
        evaluationId: evaluationId,
        ratings: ratings,
        documentPathsByKpi: documentPathsByKpi,
      );
      ref.invalidate(kraEvaluationsProvider(mode));
      ref.invalidate(kraActiveCycleProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateKraData() {
    ref.invalidate(myKrasProvider);
    ref.invalidate(managedKrasProvider);
    ref.invalidate(kraTeamMembersProvider);
    for (final mode in KraReviewMode.values) {
      ref.invalidate(kraEvaluationsProvider(mode));
    }
  }
}
