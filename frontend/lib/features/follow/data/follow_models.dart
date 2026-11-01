/// Model của tính năng theo dõi, khớp với DTO của backend (module `user`).
library;

int _toInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// Một người trong danh sách "người theo dõi" / "đang theo dõi".
class FollowUser {
  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String? jlptLevel;

  /// Mình đang theo dõi người này.
  final bool isFollowing;

  /// Người này đang theo dõi mình.
  final bool isFollowedBy;

  const FollowUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.jlptLevel,
    required this.isFollowing,
    required this.isFollowedBy,
  });

  String get name => displayName.isNotEmpty ? displayName : username;

  FollowUser copyWith({bool? isFollowing}) => FollowUser(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    jlptLevel: jlptLevel,
    isFollowing: isFollowing ?? this.isFollowing,
    isFollowedBy: isFollowedBy,
  );

  factory FollowUser.fromJson(Map<String, dynamic> json) => FollowUser(
    id: _toInt(json['id']),
    username: json['username']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
    jlptLevel: json['jlptLevel']?.toString(),
    isFollowing: json['isFollowing'] == true,
    isFollowedBy: json['isFollowedBy'] == true,
  );
}

/// Trang cá nhân công khai của một người dùng.
class PublicProfile {
  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String? jlptLevel;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int likesCount;
  final int videosCount;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isSelf;

  /// Người đang xem đã chặn người này.
  final bool isBlocked;

  const PublicProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.jlptLevel,
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
    this.videosCount = 0,
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isSelf = false,
    this.isBlocked = false,
  });

  String get name => displayName.isNotEmpty ? displayName : username;

  PublicProfile copyWith({
    bool? isFollowing,
    int? followersCount,
    bool? isBlocked,
  }) =>
      PublicProfile(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        jlptLevel: jlptLevel,
        bio: bio,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount,
        likesCount: likesCount,
        videosCount: videosCount,
        isFollowing: isFollowing ?? this.isFollowing,
        isFollowedBy: isFollowedBy,
        isSelf: isSelf,
        isBlocked: isBlocked ?? this.isBlocked,
      );

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: _toInt(json['id']),
    username: json['username']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
    jlptLevel: json['jlptLevel']?.toString(),
    bio: json['bio']?.toString() ?? '',
    followersCount: _toInt(json['followersCount']),
    followingCount: _toInt(json['followingCount']),
    likesCount: _toInt(json['likesCount']),
    videosCount: _toInt(json['videosCount']),
    isFollowing: json['isFollowing'] == true,
    isFollowedBy: json['isFollowedBy'] == true,
    isSelf: json['isSelf'] == true,
    isBlocked: json['isBlocked'] == true,
  );
}

/// Một người trong danh sách "người đã chặn".
class BlockedUser {
  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;

  const BlockedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  String get name => displayName.isNotEmpty ? displayName : username;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: _toInt(json['id']),
    username: json['username']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
  );
}
