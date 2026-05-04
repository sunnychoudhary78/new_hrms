import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/resignation/data/resignation_list_query.dart';
import 'package:lms/features/resignation/data/resignation_repo.dart';
import '../../data/resignation_api_service.dart';
import '../../data/models/resignation_model.dart';

enum ResignationRole { employee, manager, hod, hr }

final resignationRoleProvider = Provider<ResignationRole>((ref) {
  final permissions = ref.watch(authProvider).permissions;

  if (permissions.contains('resignation.hr')) return ResignationRole.hr;
  if (permissions.contains('resignation.hod')) return ResignationRole.hod;
  if (permissions.contains('resignation.manager'))
    return ResignationRole.manager;

  return ResignationRole.employee;
});

/// ======================================================
/// ✅ API SERVICE
/// ======================================================
final resignationApiServiceProvider = Provider<ResignationApiService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ResignationApiService(api);
});

/// ======================================================
/// ✅ REPOSITORY
/// ======================================================
final resignationRepositoryProvider = Provider<ResignationRepository>((ref) {
  final api = ref.read(resignationApiServiceProvider);
  return ResignationRepository(api);
});

/// ======================================================
/// ✅ MY RESIGNATION (EMPLOYEE)
/// ======================================================
/// Auto-dispose so leaving and re-opening "My Resignation" refetches status
/// after manager/HOD/HR actions (otherwise cached [Pending] persists).
final myResignationProvider = FutureProvider.autoDispose<ResignationModel?>((
  ref,
) async {
  final repo = ref.read(resignationRepositoryProvider);
  return repo.getMy();
});

/// Backend `status` filter for manager/hod/hr list (chips on dashboard).
class ResignationListFilterNotifier extends Notifier<ResignationListQuery> {
  @override
  ResignationListQuery build() => ResignationListQuery.all;

  void select(ResignationListQuery query) {
    state = query;
  }
}

final resignationListFilterProvider =
    NotifierProvider<ResignationListFilterNotifier, ResignationListQuery>(
      ResignationListFilterNotifier.new,
    );

/// ======================================================
/// ✅ DASHBOARD (MANAGER / HOD / HR)
/// ======================================================
final resignationDashboardProvider = FutureProvider<List<ResignationModel>>((
  ref,
) async {
  final repo = ref.read(resignationRepositoryProvider);
  final role = ref.watch(resignationRoleProvider);
  final filter = ref.watch(resignationListFilterProvider);

  switch (role) {
    case ResignationRole.manager:
      return repo.getManagerResignations(filter: filter);
    case ResignationRole.hod:
      return repo.getHodResignations(filter: filter);
    case ResignationRole.hr:
      return repo.getHrAll(filter: filter);
    case ResignationRole.employee:
      return const [];
  }
});

/// ======================================================
/// ✅ ACTIONS (SUBMIT / WITHDRAW / APPROVE / REJECT)
/// ======================================================
final resignationActionProvider =
    NotifierProvider<ResignationActionNotifier, AsyncValue<void>>(
      ResignationActionNotifier.new,
    );

class ResignationActionNotifier extends Notifier<AsyncValue<void>> {
  late final ResignationRepository repo;

  @override
  AsyncValue<void> build() {
    repo = ref.read(resignationRepositoryProvider);
    return const AsyncValue.data(null);
  }

  /// ───────── SUBMIT ─────────
  Future<void> submit({
    required String reason,
    String? lastWorkingDate,
    int? noticePeriodDays,
  }) async {
    if (reason.trim().isEmpty) {
      state = AsyncValue.error(
        Exception('Reason / remarks are required to submit.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      await repo.submit(
        reason: reason,
        lastWorkingDate: lastWorkingDate,
        noticePeriodDays: noticePeriodDays,
      );

      /// 🔄 Refresh
      ref.invalidate(myResignationProvider);
      ref.invalidate(resignationDashboardProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ───────── WITHDRAW ─────────
  Future<void> withdraw(String id) async {
    state = const AsyncValue.loading();

    try {
      await repo.withdraw(id);

      /// 🔄 Refresh
      ref.invalidate(myResignationProvider);
      ref.invalidate(resignationDashboardProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ───────── APPROVE ─────────
  Future<void> approve(String id, String remarks) async {
    if (remarks.trim().isEmpty) {
      state = AsyncValue.error(
        Exception('Remarks are required to approve.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      await repo.approve(id, remarks);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ───────── REJECT ─────────
  Future<void> reject(String id, String remarks) async {
    if (remarks.trim().isEmpty) {
      state = AsyncValue.error(
        Exception('Remarks are required to reject.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      await repo.reject(id, remarks);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
