import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';

class ApiService {
  final Dio _dio;
  final Ref ref;

  ApiService(this._dio, this.ref);

  // ───────── POST ─────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 POST BASE: ${_dio.options.baseUrl}");
    debugPrint("🌐 POST ENDPOINT: $endpoint");
    debugPrint("📦 BODY: $data");

    try {
      final response = await _dio.post(
        endpoint.startsWith("/") ? endpoint.substring(1) : endpoint,
        data: data,
      );

      debugPrint("✅ POST success | status=${response.statusCode}");
      debugPrint("📥 RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("POST", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── GET ─────────
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    debugPrint("🌐 GET ${_dio.options.baseUrl}$endpoint");

    if (queryParams != null) {
      debugPrint("📦 QUERY: $queryParams");
    }

    try {
      final response = await _dio.get(endpoint, queryParameters: queryParams);
      debugPrint("✅ GET success | status=${response.statusCode}");
      return _handle(response);
    } on DioException catch (e) {
      _logError("GET", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── PATCH ─────────
  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 PATCH ${_dio.options.baseUrl}$endpoint");
    debugPrint("📦 BODY: $data");

    try {
      final response = await _dio.patch(endpoint, data: data);
      debugPrint("✅ PATCH success | status=${response.statusCode}");
      return _handle(response);
    } on DioException catch (e) {
      _logError("PATCH", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── MULTIPART ─────────
  Future<dynamic> postMultipart(String endpoint, FormData formData) async {
    debugPrint("🌐 POST MULTIPART ${_dio.options.baseUrl}$endpoint");

    try {
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      debugPrint("✅ MULTIPART success | status=${response.statusCode}");
      return _handle(response);
    } on DioException catch (e) {
      _logError("POST MULTIPART", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── DELETE ─────────
  Future<dynamic> delete(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 DELETE ${_dio.options.baseUrl}$endpoint");
    debugPrint("📦 BODY: $data");

    try {
      final response = await _dio.delete(endpoint, data: data);

      debugPrint("✅ DELETE success | status=${response.statusCode}");
      return _handle(response);
    } on DioException catch (e) {
      _logError("DELETE", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── RESPONSE HANDLER ─────────
  dynamic _handle(Response response) {
    final code = response.statusCode ?? 0;

    if (code >= 200 && code < 300) {
      return response.data;
    }

    debugPrint("❌ Unexpected status code: $code");

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
    );
  }

  // ───────── ERROR LOGGER ─────────
  void _logError(String method, String endpoint, DioException e) {
    debugPrint("❌ $method failed | endpoint=$endpoint");
    debugPrint("❌ Status: ${e.response?.statusCode}");
    debugPrint("❌ Response: ${e.response?.data}");
    debugPrint("❌ DioType: ${e.type}");
  }

  // ───────── ERROR PARSER ─────────
  Exception _extractException(DioException e) {
    final auth = ref.read(authProvider);

    // 402 response from backend
    if (e.response?.statusCode == 402 ||
        (e.response?.data is Map && e.response?.data['expired'] == true)) {
      ref.read(sessionGuardProvider).trigger(() {
        ref.read(authProvider.notifier).forceSubscriptionExpired();
      });

      return Exception("SUBSCRIPTION_EXPIRED");
    }

    // Normal API error response
    if (e.response != null) {
      final data = e.response!.data;

      if (data is Map) {
        if (data['message'] != null) {
          return Exception(data['message']);
        }

        if (data['error'] != null) {
          return Exception(data['error']);
        }
      }
    }

    // Network timeout
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception("Connection timeout");
    }

    // No internet
    if (e.type == DioExceptionType.connectionError) {
      return Exception("No internet connection");
    }

    // 🔥 IMPORTANT: backend sometimes closes connection when subscription expired
    if (e.response == null && auth.profile != null) {
      ref.read(sessionGuardProvider).trigger(() {
        ref.read(authProvider.notifier).forceSubscriptionExpired();
      });

      return Exception("SESSION_EXPIRED");
    }

    return Exception("Something went wrong");
  }
}
