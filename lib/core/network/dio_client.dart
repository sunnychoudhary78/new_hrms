import 'package:dio/dio.dart';
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
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
           contentType: 'application/json',
         ),
       ) {
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
