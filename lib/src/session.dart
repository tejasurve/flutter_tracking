import 'package:uuid/uuid.dart';

class Session {
  final String sessionId;
  final String msisdn;
  final String customerId;
  String ipAddress; // make it mutable

  Session({
    required this.msisdn,
    required this.customerId,
    required this.ipAddress, // initial value, can update later
  }) : sessionId = const Uuid().v4();

  void updateIp(String newIp) {
    ipAddress = newIp;
  }
}
