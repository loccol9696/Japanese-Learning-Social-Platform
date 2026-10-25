/// Hồ sơ công khai của một người dùng (không có email).
class PublicProfile {
  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String jlptLevel;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int likesCount;
  final int videosCount;
  final bool isFollowing;
  final bool isSelf;

  const PublicProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.jlptLevel = '',
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
    this.videosCount = 0,
    this.isFollowing = false,
    this.isSelf = false,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PublicProfile(
      id: n('id'),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      jlptLevel: json['jlptLevel']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      followersCount: n('followersCount'),
      followingCount: n('followingCount'),
      likesCount: n('likesCount'),
      videosCount: n('videosCount'),
      isFollowing: json['following'] == true || json['isFollowing'] == true,
      isSelf: json['self'] == true || json['isSelf'] == true,
    );
  }

  PublicProfile copyWith({bool? isFollowing, int? followersCount}) => PublicProfile(
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
    isSelf: isSelf,
  );
}
