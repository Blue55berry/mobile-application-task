class Lead {
  final int? id;
  final String name;
  final String category;
  final String status;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? email;
  final String? description;
  final DateTime? lastCallDate;
  final int? totalCalls;
  final DateTime? assignedDate;
  final String? assignedTime;
  final bool isVip;
  final String source;
  final String? photoUrl;

  Lead({
    this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.createdAt,
    this.phoneNumber,
    this.email,
    this.description,
    this.lastCallDate,
    this.totalCalls = 0,
    this.assignedDate,
    this.assignedTime,
    this.isVip = false,
    this.source = 'crm',
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'phoneNumber': phoneNumber,
      'email': email,
      'description': description,
      'lastCallDate': lastCallDate?.toIso8601String(),
      'totalCalls': totalCalls,
      'assignedDate': assignedDate?.toIso8601String(),
      'assignedTime': assignedTime,
      'isVip': isVip ? 1 : 0,
      'source': source,
      'photoUrl': photoUrl,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      description: map['description'],
      lastCallDate: map['lastCallDate'] != null
          ? DateTime.parse(map['lastCallDate'])
          : null,
      totalCalls: map['totalCalls'] ?? 0,
      assignedDate: map['assignedDate'] != null
          ? DateTime.parse(map['assignedDate'])
          : null,
      assignedTime: map['assignedTime'],
      isVip: map['isVip'] == 1,
      source: map['source'] ?? 'crm',
      photoUrl: map['photoUrl'],
    );
  }

  Lead copyWith({
    int? id,
    String? name,
    String? category,
    String? status,
    DateTime? createdAt,
    String? phoneNumber,
    String? email,
    String? description,
    DateTime? lastCallDate,
    int? totalCalls,
    DateTime? assignedDate,
    String? assignedTime,
    bool? isVip,
    String? source,
    String? photoUrl,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      description: description ?? this.description,
      lastCallDate: lastCallDate ?? this.lastCallDate,
      totalCalls: totalCalls ?? this.totalCalls,
      assignedDate: assignedDate ?? this.assignedDate,
      assignedTime: assignedTime ?? this.assignedTime,
      isVip: isVip ?? this.isVip,
      source: source ?? this.source,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
