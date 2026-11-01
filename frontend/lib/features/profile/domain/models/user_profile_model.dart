import 'topic_model.dart';

class UserProfileModel {
  final int? id;
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String currentLevel;
  final String bio;
  final String role;
  final bool isActive;
  final int followingCount;
  final int followersCount;
  final int likesCount;
  final int videosCount;
  final String? subscriptionPlanName;
  final String? vipExpiresAt;
  final List<TopicModel> topics;
  final List<String> interests;

  const UserProfileModel({
    this.id,
    this.username = '',
    this.email = '',
    this.displayName = '',
    this.avatarUrl = '',
    this.currentLevel = 'N5',
    this.bio = '',
    this.role = 'USER',
    this.isActive = true,
    this.followingCount = 0,
    this.followersCount = 0,
    this.likesCount = 0,
    this.videosCount = 0,
    this.subscriptionPlanName,
    this.vipExpiresAt,
    this.topics = const [],
    this.interests = const [],
  });

  bool get isModerator => role.toUpperCase() == 'MODERATOR' || role.toUpperCase() == 'ADMIN';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isVip => subscriptionPlanName != null && subscriptionPlanName!.isNotEmpty;

  UserProfileModel copyWith({
    int? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? currentLevel,
    String? bio,
    String? role,
    bool? isActive,
    int? followingCount,
    int? followersCount,
    int? likesCount,
    int? videosCount,
    String? subscriptionPlanName,
    String? vipExpiresAt,
    List<TopicModel>? topics,
    List<String>? interests,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentLevel: currentLevel ?? this.currentLevel,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
      likesCount: likesCount ?? this.likesCount,
      videosCount: videosCount ?? this.videosCount,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
      topics: topics ?? this.topics,
      interests: interests ?? this.interests,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'] as List<dynamic>? ?? [];
    final topics = rawTopics
        .map((e) => TopicModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawInterests = json['interests'] as List<dynamic>?;
    final interests = rawInterests != null
        ? rawInterests.map((e) => e.toString()).toList()
        : topics.map((t) => t.name).toList();

    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return UserProfileModel(
      id: json['id'] as int? ?? json['userId'] as int?,
      username: json['username'] as String? ?? json['userName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      currentLevel: json['currentLevel'] as String? ?? json['jlptLevel'] as String? ?? 'N5',
      bio: json['bio'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      isActive: json['isActive'] as bool? ?? true,
      followingCount: parseCount(json['followingCount']),
      followersCount: parseCount(json['followersCount']),
      likesCount: parseCount(json['likesCount']),
      videosCount: parseCount(json['videosCount']),
      subscriptionPlanName: json['subscriptionPlanName'] as String?,
      vipExpiresAt: json['vipExpiresAt'] as String?,
      topics: topics,
      interests: interests,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'currentLevel': currentLevel,
      'jlptLevel': currentLevel,
      'bio': bio,
      'topicIds': topics.map((t) => t.id).toList(),
      'interests': interests,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'currentLevel': currentLevel,
      'jlptLevel': currentLevel,
      'bio': bio,
      'role': role,
      'isActive': isActive,
      'followingCount': followingCount,
      'followersCount': followersCount,
      'likesCount': likesCount,
      'videosCount': videosCount,
      'subscriptionPlanName': subscriptionPlanName,
      'vipExpiresAt': vipExpiresAt,
      'topics': topics.map((t) => t.toJson()).toList(),
      'interests': interests,
    };
  }
}
