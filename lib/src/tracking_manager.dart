import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'session.dart';
import 'ip_manager.dart';

class TrackingManager {
  static final TrackingManager _instance = TrackingManager._internal();
  factory TrackingManager() => _instance;
  TrackingManager._internal();

  late Session session;
  final List<Map<String, dynamic>> _events = [];
  Timer? _autoSendTimer;
  bool _isSending = false;

  static const int _maxBatchSize = 100;
  static const Duration _defaultInterval = Duration(seconds: 10);

  /// Initialize session with automatic IP detection
  Future<void> init({String msisdn = "", String customerId = ""}) async {
    final ip = await IpManager.getIpAddress() ?? "Unknown";
    session = Session(
      msisdn: msisdn,
      customerId: customerId,
      ipAddress: ip,
      sessionStart: DateTime.now(),
    );
    session.deviceInfo = await _getDeviceInfo();
    session.batteryStatus = await _getBatteryStatus();
    session.networkType = await _getNetworkType();
    session.geolocation = await _getGeoLocation();
    session.lastActivity = DateTime.now().toIso8601String();

    _startAutoSend();
    debugPrint("[MobileMonitorSDK] Initialized with IP: $ip");
    debugPrint(
        "[MobileMonitorSDK] Session info updated: $msisdn | $customerId | ${session.deviceInfo} | ${session.batteryStatus} | ${session.networkType} | ${session.geolocation} | ${session.lastActivity}");
  }

  /// Update user info and attach session-level device info (once)
  Future<void> updateUser({
    required String msisdn,
    required String customerId,
  }) async {
    session.msisdn = msisdn;
    session.customerId = customerId;
    session.deviceInfo = await _getDeviceInfo();
    session.batteryStatus = await _getBatteryStatus();
    session.networkType = await _getNetworkType();
    session.geolocation = await _getGeoLocation();
    session.lastActivity = DateTime.now().toIso8601String();
    debugPrint(
        "[MobileMonitorSDK] Session info updated: $msisdn | $customerId | ${session.deviceInfo} | ${session.batteryStatus} | ${session.networkType} | ${session.geolocation} | ${session.lastActivity}");

    await _sendSessionInfoToBackend();
  }

  /// Refresh IP if network changes
  Future<void> refreshIp() async {
    final newIp = await IpManager.getIpAddress() ?? session.ipAddress;
    session.updateIp(newIp);
    debugPrint("[MobileMonitorSDK] IP refreshed: $newIp");
  }

  /// Event-level device info (called only when adding an event)
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String os = "", osVersion = "", platform = "";

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      os = "Android";
      osVersion = info.version.release ?? "";
      platform = info.model ?? "";
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      os = "iOS";
      osVersion = info.systemVersion ?? "";
      platform = info.utsname.machine ?? "";
    }

    return {
      "os": os,
      "os_version": osVersion,
      "platform": platform,
      "app_version": packageInfo.version,
    };
  }

  Future<int> _getBatteryStatus() async => await Battery().batteryLevel;

  Future<String> _getNetworkType() async {
    final connectivity = Connectivity();
    try {
      final result = await connectivity.checkConnectivity();
      switch (result) {
        case ConnectivityResult.mobile:
          return "mobile";
        case ConnectivityResult.wifi:
          return "wifi";
        case ConnectivityResult.ethernet:
          return "ethernet";
        case ConnectivityResult.bluetooth:
          return "bluetooth";
        case ConnectivityResult.vpn:
          return "vpn";
        case ConnectivityResult.none:
          return "none";
        default:
          return "unknown";
      }
    } catch (_) {
      return "unknown";
    }
  }

  Future<Map<String, double>> _getGeoLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return {"lat": position.latitude, "lng": position.longitude};
    } catch (_) {
      return {"lat": 0, "lng": 0};
    }
  }

  /// Add an event (only event-level info)
  Future<void> addEvent(Map<String, dynamic> event) async {
    event["ip_address"] = session.ipAddress;
    event["session_id"] = session.sessionId;
    event["msisdn"] = session.msisdn;
    event["customer_id"] = session.customerId;
    event["deviceInfo"] = session.deviceInfo;
    event["batteryStatus"] = session.batteryStatus;
    event["networkType"] = session.networkType;
    event["geolocation"] = session.geolocation;

    // Optional: attach basic device info per event (if needed)
    event["last_activity"] = DateTime.now().toIso8601String();

    _events.add(event);
    debugPrint(
        "[MobileMonitorSDK] Queued event: ${event['type']} (total: ${_events.length})");

    if (_events.length >= _maxBatchSize) await sendEvents();
  }

  /// Send event batch to backend
  Future<void> sendEvents() async {
    if (_isSending || _events.isEmpty) return;

    _isSending = true;
    final eventsToSend = List<Map<String, dynamic>>.from(_events);
    final url = Uri.parse("http://192.168.1.64:4000/api/v1/ingest");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(eventsToSend),
      );

      if (response.statusCode == 200) {
        debugPrint(
            "[MobileMonitorSDK] Sent ${eventsToSend.length} events successfully ✅");
        _events.removeRange(0, eventsToSend.length);
      } else {
        debugPrint(
            "[MobileMonitorSDK] Failed to send events: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[MobileMonitorSDK] Error sending events: $e");
    } finally {
      _isSending = false;
    }
  }

  void _startAutoSend({Duration interval = _defaultInterval}) {
    _autoSendTimer?.cancel();
    _autoSendTimer = Timer.periodic(interval, (_) async {
      if (_events.isNotEmpty) await sendEvents();
    });
  }

  void stopAutoSend() {
    _autoSendTimer?.cancel();
    debugPrint("[MobileMonitorSDK] Auto-send stopped.");
  }

  int getSessionDuration() {
    return DateTime.now().difference(session.sessionStart).inSeconds;
  }

  /// Send session-level info once to backend
  Future<void> _sendSessionInfoToBackend() async {
    final url = Uri.parse("http://192.168.1.64:4000/api/v1/session");
    final payload = {
      "session_id": session.sessionId,
      "msisdn": session.msisdn,
      "customer_id": session.customerId,
      "ip_address": session.ipAddress,
      "session_start": session.sessionStart.toIso8601String(),
      "device_info": session.deviceInfo,
      "battery_status": session.batteryStatus,
      "network_type": session.networkType,
      "geolocation": session.geolocation,
      "last_activity": session.lastActivity,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("[MobileMonitorSDK] Session info stored successfully ✅");
      } else {
        debugPrint(
            "[MobileMonitorSDK] Failed to store session info: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[MobileMonitorSDK] Error storing session info: $e");
    }
  }
}
