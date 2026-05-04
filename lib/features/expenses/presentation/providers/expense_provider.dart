import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/network_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/expense_api_service.dart';
import '../../data/expense_repository.dart';
import '../../data/models/expense_model.dart';

/// ✅ API SERVICE
final expenseApiServiceProvider = Provider<ExpenseApiService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ExpenseApiService(apiService);
});

/// ✅ REPOSITORY
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final api = ref.read(expenseApiServiceProvider);
  return ExpenseRepository(api);
});

/// ✅ FETCH MY EXPENSES
final myExpensesProvider = FutureProvider<List<ExpenseClaim>>((ref) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));

  final repo = ref.read(expenseRepositoryProvider);

  final data = await repo.getMyExpenses();

  /// 🔍 Debug (remove later)
  print("📊 TOTAL EXPENSES FETCHED: ${data.length}");

  return data;
});

enum ExpenseDashboardRole { employee, manager, hod, accounts }

/// Default [statusFilter] for `POST /expenses/query` per role (matches backend guide).
String expenseDashboardDefaultStatusFilter(ExpenseDashboardRole role) {
  return switch (role) {
    ExpenseDashboardRole.manager => 'Pending',
    ExpenseDashboardRole.hod => 'Manager Approved',
    ExpenseDashboardRole.accounts => 'HOD Approved',
    ExpenseDashboardRole.employee => 'All',
  };
}

/// Status options shown on manager / HOD / accounts dashboard (sent as `statusFilter`).
List<String> expenseDashboardStatusChoices(ExpenseDashboardRole role) {
  return switch (role) {
    ExpenseDashboardRole.manager => const [
        'Pending',
        'Manager Approved',
        'HOD Approved',
        'Processed',
        'Rejected',
        'All',
      ],
    ExpenseDashboardRole.hod => const [
        'Manager Approved',
        'HOD Approved',
        'Processed',
        'Rejected',
        'Pending',
        'All',
      ],
    ExpenseDashboardRole.accounts => const [
        'HOD Approved',
        'Processed',
        'Rejected',
        'All',
      ],
    ExpenseDashboardRole.employee => const [],
  };
}

final expenseDashboardRoleProvider = Provider<ExpenseDashboardRole>((ref) {
  final permissions = ref.watch(authProvider).permissions;

  if (permissions.contains('expense.accounts')) {
    return ExpenseDashboardRole.accounts;
  }
  if (permissions.contains('expense.hod')) {
    return ExpenseDashboardRole.hod;
  }
  if (permissions.contains('expense.manager')) {
    return ExpenseDashboardRole.manager;
  }
  return ExpenseDashboardRole.employee;
});

/// Selected `statusFilter` for the approver dashboard (`POST /expenses/query`).
final expenseDashboardStatusFilterProvider =
    NotifierProvider<ExpenseDashboardStatusFilterNotifier, String>(
  ExpenseDashboardStatusFilterNotifier.new,
);

class ExpenseDashboardStatusFilterNotifier extends Notifier<String> {
  @override
  String build() {
    return expenseDashboardDefaultStatusFilter(
      ref.read(expenseDashboardRoleProvider),
    );
  }

  void setFilter(String status) => state = status;
}

String _expenseDashboardScope(ExpenseDashboardRole role) {
  return switch (role) {
    ExpenseDashboardRole.manager => 'manager',
    ExpenseDashboardRole.hod => 'hod',
    ExpenseDashboardRole.accounts => 'accounts',
    ExpenseDashboardRole.employee => '',
  };
}

final expenseDashboardProvider = FutureProvider<List<ExpenseClaim>>((
  ref,
) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final role = ref.watch(expenseDashboardRoleProvider);
  final statusFilter = ref.watch(expenseDashboardStatusFilterProvider);
  final repo = ref.read(expenseRepositoryProvider);

  switch (role) {
    case ExpenseDashboardRole.manager:
    case ExpenseDashboardRole.hod:
    case ExpenseDashboardRole.accounts:
      return repo.queryApproverExpenses(
        scope: _expenseDashboardScope(role),
        statusFilter: statusFilter,
      );
    case ExpenseDashboardRole.employee:
      return const [];
  }
});

/// ✅ CREATE / SUBMIT EXPENSE
final createExpenseProvider =
    NotifierProvider<CreateExpenseNotifier, AsyncValue<void>>(
      CreateExpenseNotifier.new,
    );

class CreateExpenseNotifier extends Notifier<AsyncValue<void>> {
  late final ExpenseRepository repo;

  @override
  AsyncValue<void> build() {
    repo = ref.read(expenseRepositoryProvider);
    return const AsyncValue.data(null);
  }

  Future<void> createExpense({
    required String title,
    required List<Map<String, dynamic>> items,
    bool submit = false,
    String? submitRemarks,
  }) async {
    state = const AsyncValue.loading();

    try {
      final String id = await repo.createExpense(title: title, items: items);

      print("🆔 CREATED ID IN PROVIDER: $id");

      if (submit) {
        final r = submitRemarks?.trim() ?? '';
        if (r.isEmpty) {
          throw Exception('Remarks are required to submit for approval.');
        }
        await repo.submitExpense(id, remarks: r);
        print("🚀 SUBMITTED EXPENSE ID: $id");
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      print("❌ CREATE/SUBMIT ERROR: $e");
    }
  }

  Future<void> updateDraft({
    required String claimId,
    required String title,
    required List<Map<String, dynamic>> items,
    bool submit = false,
    String? submitRemarks,
  }) async {
    state = const AsyncValue.loading();

    try {
      await repo.updateDraftExpense(id: claimId, title: title, items: items);

      if (submit) {
        final r = submitRemarks?.trim() ?? '';
        if (r.isEmpty) {
          throw Exception('Remarks are required to submit for approval.');
        }
        await repo.submitExpense(claimId, remarks: r);
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      print("❌ UPDATE DRAFT/SUBMIT ERROR: $e");
    }
  }
}
