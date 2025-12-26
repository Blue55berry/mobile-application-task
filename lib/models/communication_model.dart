class Communication {
  final int? id;
  final int leadId;
  final String type; // 'call', 'email', 'sms', 'whatsapp'
  final String direction; // 'inbound', 'outbound'
  final String? subject; // For emails
  final String? body; // Message content
  final String? phoneNumber;
  final String? emailAddress;
  final DateTime timestamp;
  final String status; // 'sent', 'delivered', 'failed', 'read', 'pending'
  final Map<String, dynamic>?
  metadata; // Additional data (duration, attachments, etc.)

  Communication({
    this.id,
    required this.leadId,
    required this.type,
    required this.direction,
    this.subject,
    this.body,
    this.phoneNumber,
    this.emailAddress,
    required this.timestamp,
    required this.status,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadId': leadId,
      'type': type,
      'direction': direction,
      'subject': subject,
      'body': body,
      'phoneNumber': phoneNumber,
      'emailAddress': emailAddress,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  factory Communication.fromMap(Map<String, dynamic> map) {
    return Communication(
      id: map['id'],
      leadId: map['leadId'],
      type: map['type'],
      direction: map['direction'],
      subject: map['subject'],
      body: map['body'],
      phoneNumber: map['phoneNumber'],
      emailAddress: map['emailAddress'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      status: map['status'],
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'])
          : null,
    );
  }

  // Helper to encode metadata as JSON string
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    return metadata.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  // Helper to decode metadata from JSON string
  static Map<String, dynamic> _decodeMetadata(String metadataStr) {
    final result = <String, dynamic>{};
    final pairs = metadataStr.split('|');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  Communication copyWith({
    int? id,
    int? leadId,
    String? type,
    String? direction,
    String? subject,
    String? body,
    String? phoneNumber,
    String? emailAddress,
    DateTime? timestamp,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return Communication(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper getters
  String get displayTitle {
    switch (type) {
      case 'email':
        return subject ?? 'Email';
      case 'sms':
        return 'SMS Message';
      case 'whatsapp':
        return 'WhatsApp Message';
      case 'call':
        return direction == 'inbound' ? 'Incoming Call' : 'Outgoing Call';
      default:
        return 'Communication';
    }
  }

  String get displayIcon {
    switch (type) {
      case 'email':
        return '📧';
      case 'sms':
        return '💬';
      case 'whatsapp':
        return '💬';
      case 'call':
        return '📞';
      default:
        return '💼';
    }
  }
}
