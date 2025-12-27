class Company {
  final int? id;
  final String name;
  final String? type;
  final String? industry;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String? logo;
  final int memberCount;
  final List<String> teamMembers; // Email addresses of team members
  final bool isActive;
  final DateTime createdAt;

  Company({
    this.id,
    required this.name,
    this.type,
    this.industry,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.logo,
    this.memberCount = 1,
    this.teamMembers = const [],
    this.isActive = true,
    required this.createdAt,
  });

  // Copy with method
  Company copyWith({
    int? id,
    String? name,
    String? type,
    String? industry,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? logo,
    int? memberCount,
    List<String>? teamMembers,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      industry: industry ?? this.industry,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      address: address ?? this.address,
      logo: logo ?? this.logo,
      memberCount: memberCount ?? this.memberCount,
      teamMembers: teamMembers ?? this.teamMembers,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // To database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'industry': industry,
      'email': email,
      'phone': phone,
      'website': website,
      'address': address,
      'logo': logo,
      'member_count': memberCount,
      'team_members': teamMembers.join(','), // Store as comma-separated string
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // From database map
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      industry: map['industry'],
      email: map['email'],
      phone: map['phone'],
      website: map['website'],
      address: map['address'],
      logo: map['logo'],
      memberCount: map['member_count'] ?? 1,
      teamMembers:
          map['team_members'] != null &&
              map['team_members'].toString().isNotEmpty
          ? map['team_members'].toString().split(',')
          : [],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Get initials for avatar
  String get initials {
    final words = name.split(' ');
    if (words.isEmpty) return 'C';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
