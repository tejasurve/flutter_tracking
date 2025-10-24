import 'package:network_info_plus/network_info_plus.dart';

class IpManager {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Get current IPv4 address (Wi-Fi or mobile)
  static Future<String?> getIpAddress() async {
    try {
      String? wifiIp = await _networkInfo.getWifiIP(); // Wi-Fi IP
      String? mobileIp = await _networkInfo.getWifiIP(); // fallback if needed
      return wifiIp ?? mobileIp ?? "Unknown";
    } catch (e) {
      print("Error getting IP: $e");
      return "Unknown";
    }
  }
}
