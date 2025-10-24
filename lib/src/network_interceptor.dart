import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'tracking_manager.dart';

class NetworkInterceptor extends Interceptor {
  final TrackingManager manager = TrackingManager();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Log request start
    debugPrint(
        "[MobileMonitorSDK] API request started: ${options.method} ${options.path}");
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Track successful API call
    final event = {
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "api_success",
      "endpoint": response.requestOptions.path,
      "status": response.statusCode,
      "response": null, // Only capture response if needed
      "timestamp": DateTime.now().toIso8601String(),
    };

    manager.addEvent(event);

    // Log success
    debugPrint(
        "[MobileMonitorSDK] API success tracked: ${response.requestOptions.path}, Status: ${response.statusCode}");
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Track failed API call
    final event = {
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "api_error",
      "endpoint": err.requestOptions.path,
      "status": err.response?.statusCode ?? 0,
      "response": err.response?.data?.toString(),
      "timestamp": DateTime.now().toIso8601String(),
    };

    manager.addEvent(event);

    // Log error
    debugPrint(
        "[MobileMonitorSDK] API error tracked: ${err.requestOptions.path}, Status: ${err.response?.statusCode ?? 0}, Response: ${err.response?.data}");

    super.onError(err, handler);
  }
}
