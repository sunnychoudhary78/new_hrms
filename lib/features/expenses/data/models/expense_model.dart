import 'dart:convert';

import 'package:lms/core/network/api_constants.dart';

/// Parses [receipt_file] from API: plain filename, JSON array string, or list.
List<String> parseExpenseReceiptNames(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  dynamic cur = raw;
  // Unwrap stringified JSON (some APIs store `receipt_file` as a JSON string, sometimes twice).
  for (var depth = 0; depth < 8 && cur is String; depth++) {
    var s = cur.toString().trim();
    if (s.isEmpty) return const [];

    if (s.startsWith('[') || s.startsWith('{')) {
      try {
        cur = jsonDecode(s);
        continue;
      } catch (_) {
        /* treat as literal filename if not valid JSON */
      }
    }

    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      try {
        cur = jsonDecode(s);
        continue;
      } catch (_) {
        cur = s.substring(1, s.length - 1).trim();
        continue;
      }
    }

    break;
  }

  if (cur is List) {
    return cur
        .map((e) => e?.toString().trim() ?? '')
        .where((x) => x.isNotEmpty)
        .toList();
  }

  final s = cur.toString().trim();
  return s.isEmpty ? const [] : [s];
}

/// Line item [receipt_file]: JSON array string, plain filename, or null — always null-safe.
List<String> parseExpenseItemReceiptFile(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String && raw.trim().isEmpty) return const [];
  return parseExpenseReceiptNames(raw);
}

class ExpenseItem {
  final String category;
  final String? description;
  final double amount;
  final String? expenseDate;

  /// Stored filenames for this line item (API may return one or many).
  final List<String> receiptFiles;

  ExpenseItem({
    required this.category,
    required this.amount,
    this.description,
    this.expenseDate,
    this.receiptFiles = const [],
  });

  List<String> get receiptImageUrls {
    return receiptFiles
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .map((n) => '${ApiConstants.expenseItemReceiptBaseUrl}$n')
        .toList();
  }

  static List<String> _receiptFilesFromJson(Map<String, dynamic> json) {
    final expanded = <String>[];

    void appendParsed(dynamic v) {
      if (v == null) return;
      if (v is Map) {
        final inner = v['files'] ??
            v['names'] ??
            v['paths'] ??
            v['items'] ??
            v['documents'];
        if (inner != null) appendParsed(inner);
        final single = v['file'] ??
            v['name'] ??
            v['path'] ??
            v['url'] ??
            v['filename'] ??
            v['file_name'];
        if (single != null) appendParsed(single);
        return;
      }
      if (v is List) {
        for (final e in v) {
          appendParsed(e);
        }
        return;
      }
      expanded.addAll(parseExpenseItemReceiptFile(v));
    }

    appendParsed(json['receipt_file']);
    appendParsed(json['receiptFile']);
    appendParsed(json['receipt_files']);
    appendParsed(json['receiptFiles']);
    appendParsed(json['receipts']);
    appendParsed(json['receipt_path']);
    appendParsed(json['receiptPath']);
    appendParsed(json['file_name']);
    appendParsed(json['fileName']);
    appendParsed(json['filename']);
    appendParsed(json['document']);
    appendParsed(json['attachment']);
    appendParsed(json['attachments']);
    appendParsed(json['documents']);

    final seen = <String>{};
    return expanded
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .where((s) => seen.add(s))
        .toList();
  }

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      category: json['category'] ?? 'Other',
      description: json['description'],
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      expenseDate:
          json['expense_date']?.toString() ?? json['expenseDate']?.toString(),
      receiptFiles: _receiptFilesFromJson(json),
    );
  }
}

class ExpenseClaim {
  /// Claim id from API (numeric or string).
  final String id;

  final String title;
  final String status;
  final double totalAmount;
  final String? employeeName;
  final List<ExpenseItem> items;

  /// Reserved; receipts are stored per line item only ([ExpenseItem.receiptFiles]).
  final List<String> claimReceiptFiles;
  final DateTime? createdAt;

  ExpenseClaim({
    required this.id,
    required this.title,
    required this.status,
    required this.totalAmount,
    this.employeeName,
    required this.items,
    this.claimReceiptFiles = const [],
    this.createdAt,
  });

  /// First legacy filename at claim level, if any.
  String? get receiptFile =>
      claimReceiptFiles.isEmpty ? null : claimReceiptFiles.first.trim();

  /// Full URL for the first claim-level attachment.
  String? get receiptImageUrl {
    final name = receiptFile?.trim();
    if (name == null || name.isEmpty) return null;
    return '${ApiConstants.expenseItemReceiptBaseUrl}$name';
  }

  List<String> get claimReceiptImageUrls => claimReceiptFiles
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .map((n) => '${ApiConstants.expenseItemReceiptBaseUrl}$n')
      .toList();

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final n = v.toInt();
      // Heuristic: epoch in seconds vs milliseconds
      if (n < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(n);
    }
    return DateTime.tryParse(v.toString());
  }

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    final claim = json['claim'];
    final Map<String, dynamic> root =
        claim is Map ? Map<String, dynamic>.from(claim) : json;

    return ExpenseClaim(
      id: root['id']?.toString() ?? '',

      title: (root['title'] ?? root['name'] ?? '').toString(),
      status: (root['status'] ?? '').toString(),

      /// ✅ Safe double parsing
      totalAmount:
          double.tryParse(
            (root['total_amount'] ?? root['amount'] ?? 0).toString(),
          ) ??
          0,

      employeeName:
          root['employee']?['name']?.toString() ??
          root['employee_name']?.toString(),

      items: (root['items'] as List? ?? [])
          .map(
            (e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),

      claimReceiptFiles: const [],

      createdAt: _parseDate(
        root['created_at'] ??
            root['createdAt'] ??
            root['updated_at'] ??
            root['submitted_at'],
      ),
    );
  }
}
