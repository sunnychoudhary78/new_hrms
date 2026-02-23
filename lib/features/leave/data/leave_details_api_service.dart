import '../../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';

class LeaveDetailsApiService {
  final ApiService api;

  LeaveDetailsApiService(this.api);

  /// Fetch leave details by ID
  Future<Map<String, dynamic>> fetchLeaveDetails(String leaveId) async {
    try {
      debugPrint("🌐 Fetching leave details for ID: $leaveId");

      final response = await api.get('leave-requests/$leaveId');

      if (response is Map<String, dynamic>) {
        debugPrint("✅ Leave details fetched successfully");
        return response;
      }

      throw Exception("Invalid leave details response format");
    } catch (e) {
      debugPrint("❌ fetchLeaveDetails error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
