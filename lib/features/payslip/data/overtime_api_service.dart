import 'package:flutter/foundation.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_service.dart';

class OvertimeApiService {
  final ApiService api;

  OvertimeApiService(this.api);

  /// ✅ Approve / reject an overtime entry. [remarks] is optional and omitted
  /// from the body when empty.
  Future<void> updateOvertimeStatus({
    required String id,
    required String status,
    String? remarks,
  }) async {
    final body = <String, dynamic>{"status": status};

    final trimmedRemarks = remarks?.trim();
    if (trimmedRemarks != null && trimmedRemarks.isNotEmpty) {
      body["remarks"] = trimmedRemarks;
    }

    try {
      debugPrint("🌐 Updating overtime entry $id → $status");
      debugPrint("📦 BODY: $body");

      await api.patch(ApiEndpoints.overtimeEntryStatus(id), body);

      debugPrint("✅ Overtime entry updated");
    } catch (e) {
      debugPrint("❌ updateOvertimeStatus error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
