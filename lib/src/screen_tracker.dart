import 'tracking_manager.dart';
import 'package:flutter/foundation.dart';

class ScreenTracker {
  static void trackScreen(String screenName) {
    final manager = TrackingManager();
    final event = {
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "screen",
      "screen": screenName,
      "timestamp": DateTime.now().toIso8601String(),
    };

    manager.addEvent(event);

    // ✅ Log screen tracking
    debugPrint("[MobileMonitorSDK] Screen tracked: $screenName, Event: $event");
  }
}
