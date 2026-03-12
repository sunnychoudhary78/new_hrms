import 'package:dio/dio.dart';

class SubscriptionInterceptor extends Interceptor {
  final Function() onSubscriptionExpired;

  SubscriptionInterceptor({required this.onSubscriptionExpired});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final path = err.requestOptions.path;

    /// Ignore endpoints that should not trigger subscription lock
    if (path.contains('/auth/logout') ||
        path.contains('/auth/unregister-fcm-token')) {
      handler.next(err);
      return;
    }

    /// Subscription expired
    if (response?.statusCode == 402) {
      onSubscriptionExpired();
    }

    handler.next(err);
  }
}
