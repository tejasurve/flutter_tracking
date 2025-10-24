import 'tracking_manager.dart';

class ScreenTracker {
  static void trackScreen(String screenName) {
    final manager = TrackingManager();
    manager.addEvent({
      "session_id": manager.session.sessionId,
      "msisdn": manager.session.msisdn,
      "customer_id": manager.session.customerId,
      "ip_address": manager.session.ipAddress,
      "type": "screen",
      "screen": screenName,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }
}
