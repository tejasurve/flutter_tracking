library mobile_monitor_sdk;

import 'package:mobile_monitor_sdk/mobile_monitor_sdk.dart';

export 'src/tracking_manager.dart';
export 'src/session.dart';
export 'src/network_interceptor.dart';
export 'src/action_tracker.dart';
export 'src/screen_tracker.dart';

void main() {
  final session = Session(
    msisdn: "9876543210",
    customerId: "C101",
    ipAddress: "0.0.0.0", // placeholder
  );

  final tracker = TrackingManager();
  tracker.init( msisdn: '', customerId: '');

}
