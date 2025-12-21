class Label {
  final int? id;
  final String name;
  final String color; // Hex color code like "#FF5733"
  final DateTime createdAt;

  Label({this.id, required this.name, required this.color, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  // Convert Label to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create Label from Map (from database)
  factory Label.fromMap(Map<String, dynamic> map) {
    return Label(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Create a copy with updated fields
  Label copyWith({int? id, String? name, String? color, DateTime? createdAt}) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Label(id: $id, name: $name, color: $color)';
  }
}
