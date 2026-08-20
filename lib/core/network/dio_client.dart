import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/core/network/auth_refresh_interceptor.dart';
import 'package:lms/core/network/subscription_interceptor.dart';
import 'api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  final Dio dio;

  DioClient({
    required TokenStorage tokenStorage,
    required VoidCallback onSubscriptionExpired,
    required VoidCallback onSessionInvalid,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: '${ApiConstants.baseUrl}/',
           connectTimeout: const Duration(seconds: 25),
           receiveTimeout: const Duration(seconds: 25),
           contentType: 'application/json',
         ),
       ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint("🚀 REQUEST");
          debugPrint("URL: ${options.uri}");
          debugPrint("METHOD: ${options.method}");
          debugPrint("HEADERS: ${options.headers}");
          debugPrint("BODY: ${options.data}");
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint("📥 RESPONSE ${response.statusCode}");
          debugPrint("${response.data}");
          handler.next(response);
        },
        onError: (e, handler) {
          debugPrint("❌ DIO ERROR");
          debugPrint("URI: ${e.requestOptions.uri}");
          debugPrint("TYPE: ${e.type}");
          debugPrint("MESSAGE: ${e.message}");
          handler.next(e);
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getJwt();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStorage: tokenStorage,
        onSessionInvalid: onSessionInvalid,
      ),
    );

    dio.interceptors.add(
      SubscriptionInterceptor(onSubscriptionExpired: onSubscriptionExpired),
    );
  }
}
