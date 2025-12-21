class CallModel {
  final String phoneNumber;
  final String? callerName;
  final DateTime callTime;
  final bool isIncoming;
  final int? duration;

  CallModel({
    required this.phoneNumber,
    this.callerName,
    required this.callTime,
    required this.isIncoming,
    this.duration,
  });
}
