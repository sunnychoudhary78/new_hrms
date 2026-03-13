import 'package:dio/dio.dart';

class SubscriptionInterceptor extends Interceptor {
  final Function() onSubscriptionExpired;

  SubscriptionInterceptor({required this.onSubscriptionExpired});

  bool _isExpired(Response? response, DioException? err) {
    if (response?.statusCode == 402) return true;

    final data = response?.data;
    if (data is Map && data['expired'] == true) return true;

    if (err?.message != null &&
        err!.message!.toLowerCase().contains("subscription")) {
      return true;
    }

    return false;
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_isExpired(response, null)) {
      onSubscriptionExpired();
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isExpired(err.response, err)) {
      onSubscriptionExpired();
    }

    handler.next(err);
  }
}
