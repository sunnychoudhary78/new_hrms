import 'package:flutter/cupertino.dart';

import '../../../core/network/api_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class LeaveApplyApiService {
  final ApiService api;

  LeaveApplyApiService(this.api);

  // ✅ WITH DOCUMENT (MAIN ONE)
  Future<Map<String, dynamic>> sendLeaveRequestWithDocument({
    required Map<String, dynamic> data,
    File? document,
  }) async {
    final multipartData = Map<String, dynamic>.from(data);
    final isHalfDay = multipartData['isHalfDay'] == true;

    // Normalize half-day payload fields before multipart serialization.
    if (isHalfDay) {
      multipartData['endDate'] = multipartData['startDate'];
      final rawHalfDayPart = multipartData['halfDayPart']?.toString().trim();
      if (rawHalfDayPart != null && rawHalfDayPart.isNotEmpty) {
        multipartData['halfDayPart'] = rawHalfDayPart.toUpperCase();
      }
    }

    debugPrint("📦 Raw data: $multipartData");
    debugPrint("📄 Document path: ${document?.path}");

    debugPrint("🌐 Preparing multipart leave request");
    final formData = FormData.fromMap(multipartData);
    if (document != null) {
      formData.files.add(
        MapEntry(
          'document',
          await MultipartFile.fromFile(
            document.path,
            filename: document.path.split('/').last,
          ),
        ),
      );
    }

    debugPrint("📤 Sending multipart request to leave-requests");
    final response = await api.postMultipart('leave-requests', formData);
    debugPrint("📥 Leave apply response received");
    debugPrint("📦 Response: $response");
    return Map<String, dynamic>.from(response as Map);
  }

  // (optional fallback)
  Future<Map<String, dynamic>> sendLeaveRequest(
    Map<String, dynamic> data,
  ) async {
    return await api.post('leave-requests', data);
  }
}
