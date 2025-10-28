import 'package:uuid/uuid.dart';

class Session {
  final String sessionId;
  String msisdn;
  String customerId;
  String ipAddress; // mutable
  DateTime sessionStart;

  // New session-level properties
  Map<String, dynamic>? deviceInfo;
  int? batteryStatus;
  String? networkType;
  Map<String, double>? geolocation;
  String? lastActivity;

  Session({
    required this.msisdn,
    required this.customerId,
    required this.ipAddress,
    DateTime? sessionStart,
    this.deviceInfo,
    this.batteryStatus,
    this.networkType,
    this.geolocation,
    this.lastActivity,
  })  : sessionId = const Uuid().v4(),
        sessionStart = sessionStart ?? DateTime.now();

  /// Update IP dynamically
  void updateIp(String newIp) {
    ipAddress = newIp;
  }

  /// Update session-level device info
  void updateDeviceInfo({
    Map<String, dynamic>? deviceInfo,
    int? batteryStatus,
    String? networkType,
    Map<String, double>? geolocation,
    String? lastActivity,
  }) {
    if (deviceInfo != null) this.deviceInfo = deviceInfo;
    if (batteryStatus != null) this.batteryStatus = batteryStatus;
    if (networkType != null) this.networkType = networkType;
    if (geolocation != null) this.geolocation = geolocation;
    if (lastActivity != null) this.lastActivity = lastActivity;
  }
}
