import 'topic_model.dart';

class UserProfileModel {
  final int? id;
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String currentLevel;
  final String bio;
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
    this.topics = const [],
    this.interests = const [],
  });

  UserProfileModel copyWith({
    int? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? currentLevel,
    String? bio,
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

    return UserProfileModel(
      id: json['id'] as int? ?? json['userId'] as int?,
      username: json['username'] as String? ?? json['userName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      currentLevel: json['currentLevel'] as String? ?? json['jlptLevel'] as String? ?? 'N5',
      bio: json['bio'] as String? ?? '',
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
      'topics': topics.map((t) => t.toJson()).toList(),
      'interests': interests,
    };
  }
}
