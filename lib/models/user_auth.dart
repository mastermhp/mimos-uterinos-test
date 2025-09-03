class UserAuth {
  final String id;
  final String name;
  final String email;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserAuth({
    required this.id,
    required this.name,
    required this.email,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory constructor for API response
  factory UserAuth.fromApiResponse(Map<String, dynamic> json) {
    return UserAuth(
      id: json['id'] ?? json['_id'], // Handle both 'id' and '_id'
      name: json['name'],
      email: json['email'],
      isVerified: json['isVerified'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // Factory constructor for local JSON (from storage)
  factory UserAuth.fromJson(Map<String, dynamic> json) {
    return UserAuth(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      isVerified: json['isVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Copy with method for updating user data
  UserAuth copyWith({
    String? id,
    String? name,
    String? email,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAuth(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserAuth(id: $id, name: $name, email: $email, isVerified: $isVerified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAuth &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.isVerified == isVerified &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        isVerified.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
