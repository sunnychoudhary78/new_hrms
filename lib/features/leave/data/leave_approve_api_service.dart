import '../../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';

class LeaveApproveApiService {
  final ApiService api;

  LeaveApproveApiService(this.api);

  /// 📥 Manager requests
  Future<List<dynamic>> fetchManagerRequests() async {
    try {
      debugPrint("🌐 Fetching manager leave requests");

      final res = await api.get('leave-requests/manager/requests/all');

      if (res is Map && res['data'] is List) {
        debugPrint("✅ Manager requests fetched: ${res['data'].length}");
        return res['data'];
      }

      if (res is List) {
        debugPrint("✅ Manager requests fetched: ${res.length}");
        return res;
      }

      throw Exception("Invalid manager request response format");
    } catch (e) {
      debugPrint("❌ fetchManagerRequests error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// ✅ APPROVE OR PARTIAL APPROVE LEAVE
  Future<void> approveLeave(
    String requestId,
    String action,
    String? comment, {
    List<String>? approvedDatesInput,
  }) async {
    final body = <String, dynamic>{"action": action, "comment": comment ?? ""};

    if (action == "partial_approve") {
      body["approvedDatesInput"] = approvedDatesInput ?? <String>[];
    }

    try {
      debugPrint("🌐 Approving leave");
      debugPrint("📦 APPROVE BODY: $body");

      final res = await api.patch('leave-requests/$requestId/status', body);

      debugPrint("✅ Leave approved successfully");
      debugPrint("📥 Response: $res");
    } catch (e) {
      debugPrint("❌ approveLeave error: $e");

      /// ApiService already extracted backend message
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// ❌ REJECT LEAVE (FINAL SAFE VERSION)
  Future<void> rejectLeave(String requestId, String? comment) async {
    final body = {"action": "reject", "comment": comment ?? ""};

    try {
      debugPrint("🌐 Rejecting leave");
      debugPrint("📦 REJECT BODY: $body");

      final res = await api.patch('leave-requests/$requestId/status', body);

      debugPrint("✅ Leave rejected successfully");
      debugPrint("📥 Response: $res");
    } catch (e) {
      debugPrint("❌ rejectLeave error: $e");

      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
