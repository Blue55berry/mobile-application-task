class CallHistory {
  final int? id;
  final int leadId;
  final DateTime callTime;
  final int duration;
  final bool isIncoming;
  final String? notes;

  CallHistory({
    this.id,
    required this.leadId,
    required this.callTime,
    required this.duration,
    required this.isIncoming,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadId': leadId,
      'callTime': callTime.toIso8601String(),
      'duration': duration,
      'isIncoming': isIncoming ? 1 : 0,
      'notes': notes,
    };
  }

  factory CallHistory.fromMap(Map<String, dynamic> map) {
    return CallHistory(
      id: map['id'],
      leadId: map['leadId'],
      callTime: DateTime.parse(map['callTime']),
      duration: map['duration'],
      isIncoming: map['isIncoming'] == 1,
      notes: map['notes'],
    );
  }
}
