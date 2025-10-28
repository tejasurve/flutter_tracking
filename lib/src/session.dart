import 'package:uuid/uuid.dart';

class Session {
  final String sessionId;
  String msisdn;
  String customerId;
  String ipAddress; // make it mutable
  DateTime sessionStart;

  Session({
    required this.msisdn,
    required this.customerId,
    required this.ipAddress, // initial value, can update later
    DateTime? sessionStart,
  })  : sessionId = const Uuid().v4(),
        sessionStart = sessionStart ?? DateTime.now();

  void updateIp(String newIp) {
    ipAddress = newIp;
  }
}
