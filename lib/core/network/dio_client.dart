import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:lms/core/network/subscription_interceptor.dart';
import 'api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  final Dio dio;

  DioClient({
    required TokenStorage tokenStorage,
    required Function() onSubscriptionExpired,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: '${ApiConstants.baseUrl}/',
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 15),
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
    // AUTH HEADER
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

    // SUBSCRIPTION PROTECTION
    dio.interceptors.add(
      SubscriptionInterceptor(onSubscriptionExpired: onSubscriptionExpired),
    );
  }
}
