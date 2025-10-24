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
  Future<void> init({
    required String msisdn,
    required String customerId,
  }) async {
    final ip = await IpManager.getIpAddress() ?? "Unknown";
    session = Session(msisdn: msisdn, customerId: customerId, ipAddress: ip);
  }

  /// Optional: refresh IP if network changes
  Future<void> refreshIp() async {
    session.updateIp(await IpManager.getIpAddress() ?? session.ipAddress);
  }

  void addEvent(Map<String, dynamic> event) {
    // Attach current IP automatically
    event["ip_address"] = session.ipAddress;
    event["session_id"] = session.sessionId;
    event["msisdn"] = session.msisdn;
    event["customer_id"] = session.customerId;

    _events.add(event);
  }

  Future<void> sendEvents() async {
    if (_events.isEmpty) return;

    final url = Uri.parse("http://localhost:4000/api/v1/ingest");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_events),
      );
      if (response.statusCode == 200) {
        _events.clear();
      } else {
        debugPrint("Failed to send events: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error sending events: $e");
    }
  }
}
