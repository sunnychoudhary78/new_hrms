import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/core/services/crypto_helper.dart';

class ApiService {
  final Dio _dio;
  final Ref ref;

  ApiService(this._dio, this.ref);

  // ───────── POST ─────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 POST BASE: ${_dio.options.baseUrl}");
    debugPrint("🌐 POST ENDPOINT: $endpoint");
    debugPrint("📦 ORIGINAL BODY: $data");

    try {
      final encryptedData = CryptoHelper.encryptPayload(data);

      debugPrint("🔐 ENCRYPTED BODY: $encryptedData");

      final response = await _dio.post(
        endpoint.startsWith("/") ? endpoint.substring(1) : endpoint,
        data: encryptedData,
      );

      debugPrint("✅ POST success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

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
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("GET", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── PATCH ─────────
  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 PATCH ${_dio.options.baseUrl}$endpoint");
    debugPrint("📦 ORIGINAL BODY: $data");

    try {
      final encryptedData = CryptoHelper.encryptPayload(data);

      debugPrint("🔐 ENCRYPTED BODY: $encryptedData");

      final response = await _dio.patch(endpoint, data: encryptedData);

      debugPrint("✅ PATCH success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("PATCH", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── DELETE ─────────
  Future<dynamic> delete(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 DELETE ${_dio.options.baseUrl}$endpoint");
    debugPrint("📦 ORIGINAL BODY: $data");

    try {
      final encryptedData = CryptoHelper.encryptPayload(data);

      debugPrint("🔐 ENCRYPTED BODY: $encryptedData");

      final response = await _dio.delete(endpoint, data: encryptedData);

      debugPrint("✅ DELETE success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("DELETE", endpoint, e);
      throw _extractException(e);
    }
  }

  Future<dynamic> deleteNoBody(String endpoint) async {
    final path = endpoint.startsWith("/") ? endpoint.substring(1) : endpoint;
    debugPrint("🌐 DELETE ${_dio.options.baseUrl}$path");

    try {
      final response = await _dio.delete(path);

      debugPrint("✅ DELETE success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("DELETE", endpoint, e);
      throw _extractException(e);
    }
  }

  Future<dynamic> postMultipart(String endpoint, FormData formData) async {
    final path = endpoint.startsWith("/") ? endpoint.substring(1) : endpoint;
    debugPrint("🌐 POST MULTIPART ${_dio.options.baseUrl}$path");
    final ct =
        '${Headers.multipartFormDataContentType}; boundary=${formData.boundary}';
    debugPrint("📎 Content-Type: $ct");

    try {
      // [DioClient] sets BaseOptions.contentType to application/json. For
      // FormData that would send the wrong major type. Pin multipart + the
      // same boundary as [formData] (Dio will still stream the body correctly).
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(contentType: ct),
      );

      debugPrint("✅ MULTIPART success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("POST MULTIPART", endpoint, e);
      throw _extractException(e);
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    debugPrint("🌐 PUT ${_dio.options.baseUrl}$endpoint");
    debugPrint("📦 ORIGINAL BODY: $data");

    try {
      final encryptedData = CryptoHelper.encryptPayload(data);

      debugPrint("🔐 ENCRYPTED BODY: $encryptedData");

      final response = await _dio.put(endpoint, data: encryptedData);

      debugPrint("✅ PUT success | status=${response.statusCode}");
      debugPrint("📥 RAW RESPONSE: ${response.data}");

      return _handle(response);
    } on DioException catch (e) {
      _logError("PUT", endpoint, e);
      throw _extractException(e);
    }
  }

  // ───────── RESPONSE HANDLER (DECRYPT HERE) ─────────
  dynamic _handle(Response response) {
    final code = response.statusCode ?? 0;

    if (code >= 200 && code < 300) {
      try {
        final decrypted = CryptoHelper.decryptPayload(response.data);

        debugPrint("🔓 DECRYPTED RESPONSE: $decrypted");

        return decrypted;
      } catch (e) {
        debugPrint("❌ DECRYPTION FAILED: $e");
        return response.data; // fallback
      }
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

    /// 🔥 STEP 1: capture raw error
    dynamic rawError = e.response?.data;

    debugPrint("🔥 RAW ERROR (ENCRYPTED): $rawError");

    /// 🔓 STEP 2: try decrypt
    dynamic errorData;

    try {
      errorData = CryptoHelper.decryptPayload(rawError);
      debugPrint("🔓 DECRYPTED ERROR: $errorData");
    } catch (err) {
      debugPrint("❌ ERROR DECRYPT FAILED: $err");
      errorData = rawError;
    }

    // ───────── SUBSCRIPTION EXPIRED ─────────
    if (e.response?.statusCode == 402 ||
        (errorData is Map && errorData['expired'] == true)) {
      ref.read(sessionGuardProvider).trigger(() {
        ref.read(authProvider.notifier).forceSubscriptionExpired();
      });

      return Exception("SUBSCRIPTION_EXPIRED");
    }

    // ───────── NORMAL API ERROR ─────────
    if (errorData is Map) {
      if (errorData['message'] != null) {
        return Exception(errorData['message']);
      }

      if (errorData['error'] != null) {
        return Exception(errorData['error']);
      }
    }

    // ───────── NETWORK TIMEOUT ─────────
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception("Connection timeout");
    }

    // ───────── NO INTERNET ─────────
    if (e.type == DioExceptionType.connectionError) {
      return Exception("No internet connection");
    }

    // ───────── SESSION EXPIRED FALLBACK ─────────
    if (e.response == null && auth.profile != null) {
      ref.read(sessionGuardProvider).trigger(() {
        ref.read(authProvider.notifier).forceSubscriptionExpired();
      });

      return Exception("SESSION_EXPIRED");
    }

    return Exception("Something went wrong");
  }
}
