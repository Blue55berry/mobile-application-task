class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime loginDate;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.loginDate,
  });

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'loginDate': loginDate.toIso8601String(),
    };
  }

  /// Create from Map (database)
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      photoUrl: map['photoUrl'] as String?,
      loginDate: DateTime.parse(map['loginDate'] as String),
    );
  }

  /// Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'loginDate': loginDate.toIso8601String(),
    };
  }

  /// Create from JSON (SharedPreferences)
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      loginDate: DateTime.parse(json['loginDate'] as String),
    );
  }

  /// Copy with method for updates
  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? loginDate,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      loginDate: loginDate ?? this.loginDate,
    );
  }

  /// Get first letter of name for avatar fallback
  String get initial {
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, displayName: $displayName)';
  }
}
