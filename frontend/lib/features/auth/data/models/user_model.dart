class UserModel {
  final int? id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? jlptLevel;
  final String? bio;
  final String? role;
  final bool? isActive;
  final String? createdAt;

  const UserModel({
    this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.jlptLevel,
    this.bio,
    this.role,
    this.isActive,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      jlptLevel: json['jlptLevel'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] as String?,
      isActive: json['isActive'] as bool?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'jlptLevel': jlptLevel,
      'bio': bio,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}
