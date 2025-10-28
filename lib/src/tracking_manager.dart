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

  static const int _maxBatchSize = 100; // safety limit
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

    // Start background auto-send
    _startAutoSend();
    debugPrint("[MobileMonitorSDK] Initialized with IP: $ip");
  }

  /// Update user info dynamically after login and attach session-level device info
  Future<void> updateUser({
    required String msisdn,
    required String customerId,
  }) async {
    session.msisdn = msisdn;
    session.customerId = customerId;

    // Attach device/session info at session level
    session.deviceInfo = await _getDeviceInfo();
    session.batteryStatus = await _getBatteryStatus();
    session.networkType = await _getNetworkType();
    session.geolocation = await _getGeoLocation();
    session.lastActivity = DateTime.now().toIso8601String();

    debugPrint("[MobileMonitorSDK] Updated user & session info: $msisdn | $customerId");
  }

  /// Refresh IP if network changes
  Future<void> refreshIp() async {
    final newIp = await IpManager.getIpAddress() ?? session.ipAddress;
    session.updateIp(newIp);
    debugPrint("[MobileMonitorSDK] IP refreshed: $newIp");
  }

  /// Get device info and app version
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String os = "";
    String osVersion = "";
    String platform = "";

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

  /// Get battery status
  Future<int> _getBatteryStatus() async {
    final battery = Battery();
    return await battery.batteryLevel;
  }

  /// Get network type
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

  /// Get geolocation
  Future<Map<String, double>> _getGeoLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return {"lat": position.latitude, "lng": position.longitude};
    } catch (_) {
      return {"lat": 0, "lng": 0}; // fallback
    }
  }

  /// Add an event and flush automatically if limit reached
  Future<void> addEvent(Map<String, dynamic> event) async {
    // Attach basic session info
    event["ip_address"] = session.ipAddress;
    event["session_id"] = session.sessionId;
    event["msisdn"] = session.msisdn;
    event["customer_id"] = session.customerId;

    // Attach device and app info per event
    event["device_info"] = await _getDeviceInfo();
    event["battery_status"] = await _getBatteryStatus();
    event["network_type"] = await _getNetworkType();
    event["geolocation"] = await _getGeoLocation();
    event["last_activity"] = DateTime.now().toIso8601String();

    _events.add(event);

    debugPrint("[MobileMonitorSDK] Queued event: ${event['type']} (total: ${_events.length})");

    if (_events.length >= _maxBatchSize) {
      debugPrint("[MobileMonitorSDK] Max batch size reached. Sending now...");
      await sendEvents();
    }
  }

  /// Send events batch to the server
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
        debugPrint("[MobileMonitorSDK] Sent ${eventsToSend.length} events successfully ✅");
        _events.removeRange(0, eventsToSend.length);
      } else {
        debugPrint("[MobileMonitorSDK] Failed to send events: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[MobileMonitorSDK] Error sending events: $e");
    } finally {
      _isSending = false;
    }
  }

  /// Background auto-send (runs every 10 sec by default)
  void _startAutoSend({Duration interval = _defaultInterval}) {
    _autoSendTimer?.cancel();
    _autoSendTimer = Timer.periodic(interval, (_) async {
      if (_events.isNotEmpty) {
        debugPrint("[MobileMonitorSDK] Auto-sending ${_events.length} queued events...");
        await sendEvents();
      }
    });
    debugPrint("[MobileMonitorSDK] Auto-send started (interval: ${interval.inSeconds}s)");
  }

  /// Stop auto-sending (e.g., on app dispose or logout)
  void stopAutoSend() {
    _autoSendTimer?.cancel();
    debugPrint("[MobileMonitorSDK] Auto-send stopped.");
  }

  /// Get current session duration in seconds
  int getSessionDuration() {
    return DateTime.now().difference(session.sessionStart).inSeconds;
  }
}
