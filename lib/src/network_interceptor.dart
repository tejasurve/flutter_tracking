import 'package:dio/dio.dart';
import 'tracking_manager.dart';

class NetworkInterceptor extends Interceptor {
  final TrackingManager manager = TrackingManager();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // You can optionally log request start here
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Track successful API call
    manager.addEvent({
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "api_success",
      "endpoint": response.requestOptions.path,
      "status": response.statusCode,
      "response": null,
      "timestamp": DateTime.now().toIso8601String(),
    });

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Track failed API call
    manager.addEvent({
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "api_error",
      "endpoint": err.requestOptions.path,
      "status": err.response?.statusCode ?? 0,
      "response": err.response?.data?.toString(),
      "timestamp": DateTime.now().toIso8601String(),
    });

    super.onError(err, handler);
  }
}
