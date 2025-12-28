class AutomaticMessage {
  final int? id;
  final String name;
  final String message;
  final String trigger;
  final bool isEnabled;
  final DateTime createdAt;

  AutomaticMessage({
    this.id,
    required this.name,
    required this.message,
    required this.trigger,
    this.isEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'message': message,
      'trigger': trigger,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AutomaticMessage.fromMap(Map<String, dynamic> map) {
    return AutomaticMessage(
      id: map['id'] as int?,
      name: map['name'] as String,
      message: map['message'] as String,
      trigger: map['trigger'] as String,
      isEnabled: (map['is_enabled'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  AutomaticMessage copyWith({
    int? id,
    String? name,
    String? message,
    String? trigger,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return AutomaticMessage(
      id: id ?? this.id,
      name: name ?? this.name,
      message: message ?? this.message,
      trigger: trigger ?? this.trigger,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
