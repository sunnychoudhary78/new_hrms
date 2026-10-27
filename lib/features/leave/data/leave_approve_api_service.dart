import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';

class LeaveApproveApiService {
  final ApiService api;

  LeaveApproveApiService(this.api);

  /// 📥 Manager requests
  Future<List<dynamic>> fetchManagerRequests() async {
    try {
      debugPrint("🌐 Fetching manager leave requests");

      const pageSize = 100;
      final rows = <dynamic>[];
      var page = 1;
      var totalPages = 1;

      do {
        final res = await api.get(
          'leave-requests/manager/requests/all',
          queryParams: {"page": page, "limit": pageSize},
        );

        if (res is List) {
          debugPrint("✅ Manager requests fetched: ${res.length}");
          return res;
        }

        if (res is Map && res['data'] is List) {
          rows.addAll(res['data'] as List);
          final meta = res['meta'];
          if (meta is Map && meta['totalPages'] != null) {
            totalPages =
                int.tryParse(meta['totalPages'].toString()) ?? totalPages;
          } else {
            break;
          }
        } else {
          throw Exception("Invalid manager request response format");
        }

        page++;
      } while (page <= totalPages);

      debugPrint("✅ Manager requests fetched: ${rows.length}");
      return rows;
    } catch (e) {
      debugPrint("❌ fetchManagerRequests error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// ⏳ Pending-only requests for the logged-in manager.
  Future<List<dynamic>> fetchManagerPendingRequests() async {
    const pageSize = 100;
    final rows = <dynamic>[];
    var page = 1;
    var totalPages = 1;

    try {
      do {
        final res = await api.get(
          ApiEndpoints.leaveManagerPending,
          queryParams: {"page": page, "limit": pageSize},
        );

        if (res is List) return res;

        if (res is Map && res['data'] is List) {
          rows.addAll(res['data'] as List);
          final meta = res['meta'];
          if (meta is Map && meta['totalPages'] != null) {
            totalPages =
                int.tryParse(meta['totalPages'].toString()) ?? totalPages;
          } else {
            break;
          }
        } else {
          throw Exception("Invalid manager pending response format");
        }

        page++;
      } while (page <= totalPages);

      return rows;
    } catch (e) {
      debugPrint("❌ fetchManagerPendingRequests error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// 📋 Unified list route (scope = "manager" | "user") with pagination/filters.
  Future<Map<String, dynamic>> queryLeaveRequests({
    required String scope,
    int page = 1,
    int limit = 100,
    Map<String, dynamic>? filters,
  }) async {
    final body = <String, dynamic>{
      "scope": scope,
      "page": page,
      "limit": limit,
      ...?filters,
    };

    try {
      debugPrint("🌐 Querying leave requests | scope=$scope");
      final res = await api.post(ApiEndpoints.leaveRequestsQuery, body);
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint("❌ queryLeaveRequests error: $e");
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
    final body = <String, dynamic>{"action": action};

    final trimmedComment = comment?.trim();
    if (trimmedComment != null && trimmedComment.isNotEmpty) {
      body["comment"] = trimmedComment;
    }

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
  Future<void> rejectLeave(
    String requestId,
    String? comment, {
    String action = "reject",
  }) async {
    final body = <String, dynamic>{"action": action};

    final trimmedComment = comment?.trim();
    if (trimmedComment != null && trimmedComment.isNotEmpty) {
      body["comment"] = trimmedComment;
    }

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
