import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/services/crypto_helper.dart';
import 'package:lms/core/storage/token_storage.dart';

/// Retries a 401 once after exchanging the stored refresh token for a new JWT.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.onSessionInvalid,
  });

  final Dio dio;
  final TokenStorage tokenStorage;
  final VoidCallback onSessionInvalid;

  Completer<bool>? _refreshCompleter;

  static const _skipFragments = [
    ApiEndpoints.login,
    ApiEndpoints.sendOtp,
    ApiEndpoints.verifyOtp,
    ApiEndpoints.forgotPassword,
    ApiEndpoints.resetPassword,
    ApiEndpoints.refreshToken,
    ApiEndpoints.unregisterFcmToken,
  ];

  bool _shouldSkip(RequestOptions options) {
    if (options.extra['skipAuthRefresh'] == true) return true;
    final path = options.path.toLowerCase();
    return _skipFragments.any((s) => path.contains(s.toLowerCase()));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _shouldSkip(err.requestOptions)) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      onSessionInvalid();
      handler.next(err);
      return;
    }

    final token = await tokenStorage.getJwt();
    final req = err.requestOptions;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.extra['skipAuthRefresh'] = true;

    try {
      final response = await dio.fetch(req);
      handler.resolve(response);
    } catch (e) {
      handler.next(e is DioException ? e : err);
    }
  }

  Future<bool> _refreshAccessToken() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refresh = await tokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: '${ApiConstants.baseUrl}/',
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
          contentType: 'application/json',
        ),
      );

      final res = await refreshDio.post(
        ApiEndpoints.refreshToken,
        data: CryptoHelper.encryptPayload({'refreshToken': refresh}),
      );

      final data = CryptoHelper.decryptPayload(res.data);
      final token = data is Map ? data['token']?.toString() : null;
      if (token == null || token.isEmpty) {
        completer.complete(false);
        return false;
      }

      await tokenStorage.saveJwt(token);
      completer.complete(true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthRefreshInterceptor: refresh failed: $e');
      }
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      if (_refreshCompleter == completer) {
        _refreshCompleter = null;
      }
    }
  }
}
