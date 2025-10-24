import 'tracking_manager.dart';
import 'package:flutter/foundation.dart';

class ActionTracker {
  static void trackAction(String screenName, String description) {
    final manager = TrackingManager();
    final event = {
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "action",
      "screen": screenName,
      "description": description,
      "timestamp": DateTime.now().toIso8601String(),
    };

    manager.addEvent(event);

    // ✅ Log action tracking
    debugPrint(
        "[MobileMonitorSDK] Action tracked: Screen=$screenName, Description=$description, Event=$event");
  }
}
