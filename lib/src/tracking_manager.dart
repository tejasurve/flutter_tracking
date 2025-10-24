import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'ip_manager.dart';

class TrackingManager {
  static final TrackingManager _instance = TrackingManager._internal();
  factory TrackingManager() => _instance;
  TrackingManager._internal();

  late Session session;
  final List<Map<String, dynamic>> _events = [];

  /// Initialize session with automatic IP detection
  Future<void> init({String msisdn = "", String customerId = ""}) async {
    final ip = await IpManager.getIpAddress() ?? "Unknown";
    session = Session(
      msisdn: msisdn,
      customerId: customerId,
      ipAddress: ip,
    );
    debugPrint(
        "[MobileMonitorSDK] Session initialized: sessionId=${session.sessionId}, IP=${session.ipAddress}, MSISDN=${session.msisdn}, CustomerID=${session.customerId}");
  }

  /// Dynamically update user info after login
  void updateUser({required String msisdn, required String customerId}) {
    session.msisdn = msisdn;
    session.customerId = customerId;
    debugPrint(
        "[MobileMonitorSDK] User info updated: MSISDN=${session.msisdn}, CustomerID=${session.customerId}");
  }

  /// Optional: refresh IP if network changes
  Future<void> refreshIp() async {
    final oldIp = session.ipAddress;
    final newIp = await IpManager.getIpAddress() ?? oldIp;
    session.updateIp(newIp);
    debugPrint("[MobileMonitorSDK] IP updated: $oldIp -> $newIp");
  }

  void addEvent(Map<String, dynamic> event) {
    // Attach current IP automatically
    event["ip_address"] = session.ipAddress;
    event["session_id"] = session.sessionId;
    event["msisdn"] = session.msisdn;
    event["customer_id"] = session.customerId;

    _events.add(event);

    debugPrint("[MobileMonitorSDK] Event added: ${event.toString()}");
  }

  Future<void> sendEvents() async {
    if (_events.isEmpty) {
      debugPrint("[MobileMonitorSDK] No events to send");
      return;
    }

    final url = Uri.parse("http://192.168.1.64:4000/api/v1/ingest");
    debugPrint("[MobileMonitorSDK] Sending ${_events.length} events to $url");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_events),
      );

      if (response.statusCode == 200) {
        debugPrint("[MobileMonitorSDK] Events sent successfully");
        _events.clear();
      } else {
        debugPrint(
            "[MobileMonitorSDK] Failed to send events: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("[MobileMonitorSDK] Error sending events: $e");
    }
  }
}
