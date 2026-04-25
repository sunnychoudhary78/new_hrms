import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_service.dart';

class ExpenseApiService {
  final ApiService api;

  ExpenseApiService(this.api);

  /// Whole numbers encode as JSON integers; others as doubles (backend-friendly).
  static Object _jsonAmountForPayload(dynamic a) {
    if (a is int) return a;
    if (a is num) {
      if (a == a.roundToDouble() && a.abs() < 0x7fffffff) return a.toInt();
      return a;
    }
    final n = double.tryParse(a.toString());
    if (n == null) return 0;
    if (n == n.roundToDouble() && n.abs() < 0x7fffffff) return n.toInt();
    return n;
  }

  static MediaType? _receiptContentTypeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.webp':
        return MediaType('image', 'webp');
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.heic':
        return MediaType('image', 'heic');
      default:
        return null;
    }
  }

  /// POST `/expenses/query` — scope + statusFilter define the queue (backend expense guide).
  /// Scopes: `my` (employee), `manager`, `hod`, `accounts`.
  Future<dynamic> queryExpenseClaims({
    required String scope,
    String statusFilter = 'All',
    int page = 1,
    int limit = 10,
  }) {
    return api.post(ApiEndpoints.expensesQuery, {
      'scope': scope,
      'page': page,
      'limit': limit,
      'statusFilter': statusFilter,
    });
  }

  /// Each item may carry local-only paths in `_receiptPaths` / `receipt_paths`.
  /// The API expects a flat `receipts` multipart list and `itemFileCounts` to map
  /// files to line items (same order as [items]).
  /// Optional [claimReceiptPath] is sent as the first file(s) for item 0.
  Future<Map<String, dynamic>> createExpense({
    required String title,
    required List<Map<String, dynamic>> items,
  }) async {
    List<String> _localReceiptPaths(Map<String, dynamic> e) {
      final v = e["_receiptPaths"] ?? e["receipt_paths"];
      if (v is List) {
        return v
            .map((x) => x?.toString().trim() ?? "")
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    String _normalizeExpenseDate(String? raw) {
      final t = raw?.toString().trim() ?? "";
      if (t.isNotEmpty) return t;
      final d = DateTime.now();
      return "${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
    }

    // ✅ Build per-item file mapping
    final perItemFiles = <List<String>>[];
    for (final item in items) {
      perItemFiles.add(_localReceiptPaths(item));
    }

    // ✅ Build counts + flat files
    final itemFileCounts = perItemFiles.map((list) => list.length).toList();
    final flatFiles = perItemFiles.expand((list) => list).toList();

    // ✅ Clean items payload
    final safeItems = items.map((e) {
      return {
        "category": (e["category"] ?? "").toString(),
        "description": (e["description"] ?? "").toString(),
        "amount": _jsonAmountForPayload(e["amount"]),
        "expense_date": _normalizeExpenseDate(e["expense_date"]?.toString()),
      };
    }).toList();

    final String itemsJson = jsonEncode(safeItems);

    // ✅ Build multipart files
    final receiptParts = <MultipartFile>[];
    for (final filePath in flatFiles) {
      final ct = _receiptContentTypeForPath(filePath);
      receiptParts.add(
        await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
          contentType: ct,
        ),
      );
    }

    // ✅ Safety check (important)
    final sumCounts = itemFileCounts.fold<int>(0, (a, b) => a + b);
    if (sumCounts != receiptParts.length) {
      throw Exception(
        "Mismatch: itemFileCounts=$itemFileCounts vs files=${receiptParts.length}",
      );
    }

    // ✅ Build FormData
    final formData = FormData();

    formData.fields.add(MapEntry("title", title.trim()));
    formData.fields.add(MapEntry("items", itemsJson));

    // Backend expects one field: JSON array string, e.g. "[2,1]" (file counts per line item).
    formData.fields.add(MapEntry("itemFileCounts", jsonEncode(itemFileCounts)));

    // Flat multipart list in the same order as counts (Dio repeats the same field name).
    for (final part in receiptParts) {
      formData.files.add(MapEntry("receipts", part));
    }

    print(
      "createExpense multipart: itemFileCounts=$itemFileCounts files=${receiptParts.length}",
    );

    final res = await api.postMultipart(ApiEndpoints.expenses, formData);

    if (res == null || res['data'] == null) {
      throw Exception("Invalid create expense response");
    }

    return res;
  }

  /// ───────── SUBMIT EXPENSE (DRAFT → PENDING) ─────────
  Future<void> submitExpense(String id) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    /// 🔍 Debug
    print("🚀 SUBMIT EXPENSE ID: $id");

    await api.put('${ApiEndpoints.expenses}/$id/submit', {});
  }

  /// ───────── APPROVE EXPENSE ─────────
  Future<void> approveExpense(String id, {String? remarks}) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    final body = <String, dynamic>{};
    if (remarks != null && remarks.trim().isNotEmpty) {
      body["remarks"] = remarks.trim();
    }
    await api.put('${ApiEndpoints.expenses}/$id/approve', body);
  }

  /// ───────── PAY (ACCOUNTS → PROCESSED) — `PUT /expenses/{id}/pay` ─────────
  Future<void> payExpense(
    String id, {
    String? remarks,
    String? paymentMode,
    String? paymentReference,
  }) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    final body = <String, dynamic>{};
    if (remarks != null && remarks.trim().isNotEmpty) {
      body["remarks"] = remarks.trim();
    }
    if (paymentMode != null && paymentMode.trim().isNotEmpty) {
      body["payment_mode"] = paymentMode.trim();
    }
    if (paymentReference != null && paymentReference.trim().isNotEmpty) {
      body["payment_reference"] = paymentReference.trim();
    }
    await api.put('${ApiEndpoints.expenses}/$id/pay', body);
  }

  /// ───────── REJECT EXPENSE ─────────
  Future<void> rejectExpense(String id, {String? remarks}) async {
    if (id.isEmpty) {
      throw Exception("Invalid expense ID");
    }

    final body = <String, dynamic>{};
    if (remarks != null && remarks.trim().isNotEmpty) {
      body["remarks"] = remarks.trim();
    }
    await api.put('${ApiEndpoints.expenses}/$id/reject', body);
  }
}
