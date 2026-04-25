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

final expenseDashboardProvider = FutureProvider<List<ExpenseClaim>>((
  ref,
) async {
  ref.watch(authProvider.select((s) => s.profile?.userId));
  final role = ref.watch(expenseDashboardRoleProvider);
  final repo = ref.read(expenseRepositoryProvider);

  switch (role) {
    case ExpenseDashboardRole.manager:
      return repo.getManagerPendingExpenses();
    case ExpenseDashboardRole.hod:
      return repo.getHodPendingExpenses();
    case ExpenseDashboardRole.accounts:
      return repo.getAccountsAllExpenses();
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
  }) async {
    state = const AsyncValue.loading();

    try {
      final String id = await repo.createExpense(title: title, items: items);

      print("🆔 CREATED ID IN PROVIDER: $id");

      if (submit) {
        await repo.submitExpense(id);
        print("🚀 SUBMITTED EXPENSE ID: $id");
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      print("❌ CREATE/SUBMIT ERROR: $e");
    }
  }
}
