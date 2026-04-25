import 'package:lms/features/expenses/data/models/expense_model.dart';
import 'expense_api_service.dart';

class ExpenseRepository {
  final ExpenseApiService api;

  ExpenseRepository(this.api);

  List<ExpenseClaim> _sortNewestFirst(List<ExpenseClaim> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final ta = a.createdAt;
      final tb = b.createdAt;
      if (ta != null && tb != null) return tb.compareTo(ta);
      if (ta != null) return -1;
      if (tb != null) return 1;
      return 0;
    });
    return copy;
  }

  Future<List<ExpenseClaim>> _queryAllPages({
    required String scope,
    required String statusFilter,
  }) async {
    final List<ExpenseClaim> all = [];
    var page = 1;
    const limit = 100;

    while (true) {
      final res = await api.queryExpenseClaims(
        scope: scope,
        statusFilter: statusFilter,
        page: page,
        limit: limit,
      );
      all.addAll(_mapExpenseList(res));

      final meta = res['meta'];
      final totalPages = meta is Map
          ? (meta['totalPages'] ?? meta['total_pages'])
          : null;
      final tp = totalPages is num ? totalPages.toInt() : null;
      final data = res['data'] as List? ?? res['rows'] as List? ?? [];
      if (tp != null && page >= tp) break;
      if (data.isEmpty || data.length < limit) break;
      page++;
    }

    return _sortNewestFirst(all);
  }

  /// ───────── GET MY EXPENSES ─────────
  Future<List<ExpenseClaim>> getMyExpenses() =>
      _queryAllPages(scope: 'my', statusFilter: 'All');

  List<ExpenseClaim> _mapExpenseList(dynamic response) {
    final dynamic rawRows = response['rows'] ?? response['data'];
    final List rows = rawRows is List ? rawRows : const [];

    final mapped = rows
        .whereType<Map<String, dynamic>>()
        .map(ExpenseClaim.fromJson)
        .toList();
    return _sortNewestFirst(mapped);
  }

  /// ───────── GET DASHBOARD EXPENSES (APPROVER) ─────────
  Future<List<ExpenseClaim>> getManagerPendingExpenses() =>
      _queryAllPages(scope: 'manager', statusFilter: 'Pending');

  Future<List<ExpenseClaim>> getHodPendingExpenses() => _queryAllPages(
        scope: 'hod',
        statusFilter: 'Manager Approved',
      );

  Future<List<ExpenseClaim>> getAccountsAllExpenses() => _queryAllPages(
        scope: 'accounts',
        statusFilter: 'HOD Approved',
      );

  /// ───────── CREATE EXPENSE (RETURNS CLAIM ID) ─────────
  Future<String> createExpense({
    required String title,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await api.createExpense(title: title, items: items);

    final id = res['data']?['id']?.toString();

    if (id == null || id.isEmpty) {
      throw Exception("Failed to extract claim ID");
    }

    print("🆔 CREATED EXPENSE ID: $id");

    return id;
  }

  /// ───────── SUBMIT EXPENSE ─────────
  Future<void> submitExpense(String id) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    /// 🔍 Debug
    print("🚀 SUBMITTING EXPENSE ID: $id");

    await api.submitExpense(id);
  }

  /// ───────── APPROVE EXPENSE ─────────
  Future<void> approveExpense(String id, {String? remarks}) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    await api.approveExpense(id, remarks: remarks);
  }

  /// ───────── PAY (ACCOUNTS) ─────────
  Future<void> payExpense(
    String id, {
    String? remarks,
    String? paymentMode,
    String? paymentReference,
  }) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    await api.payExpense(
      id,
      remarks: remarks,
      paymentMode: paymentMode,
      paymentReference: paymentReference,
    );
  }

  /// ───────── REJECT EXPENSE ─────────
  Future<void> rejectExpense(String id, {String? remarks}) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    await api.rejectExpense(id, remarks: remarks);
  }
}
