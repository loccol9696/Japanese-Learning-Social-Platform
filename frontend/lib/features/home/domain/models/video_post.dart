import 'ruby_segment.dart';

class VideoPost {
  final String id;
  final String backgroundImageUrl;
  final String videoUrl;
  final String creatorName;
  final String creatorTag;
  final String creatorAvatarUrl;
  final String accentInfo;
  final String jlptLevel;
  final String topicTag;
  final List<RubySegment> rubySegments;
  final List<SubtitleCue> subtitleCues;
  final String translation;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  // Chuỗi ngày học / XP của người xem: null khi backend chưa cung cấp (ẩn huy hiệu)
  final int? streakDays;
  final int? xp;
  final bool isLiked;
  final bool isFollowing;
  final double progress;
  final bool isLightBackground;

  const VideoPost({
    required this.id,
    required this.backgroundImageUrl,
    this.videoUrl = '',
    required this.creatorName,
    required this.creatorTag,
    required this.creatorAvatarUrl,
    required this.accentInfo,
    required this.jlptLevel,
    required this.topicTag,
    required this.rubySegments,
    this.subtitleCues = const [],
    required this.translation,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.viewCount = 0,
    this.streakDays,
    this.xp,
    this.isLiked = false,
    this.isFollowing = false,
    this.progress = 0.4,
    this.isLightBackground = false,
  });

  VideoPost copyWith({
    String? id,
    String? backgroundImageUrl,
    String? videoUrl,
    String? creatorName,
    String? creatorTag,
    String? creatorAvatarUrl,
    String? accentInfo,
    String? jlptLevel,
    String? topicTag,
    List<RubySegment>? rubySegments,
    List<SubtitleCue>? subtitleCues,
    String? translation,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? viewCount,
    int? streakDays,
    int? xp,
    bool? isLiked,
    bool? isFollowing,
    double? progress,
    bool? isLightBackground,
  }) {
    return VideoPost(
      id: id ?? this.id,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      creatorName: creatorName ?? this.creatorName,
      creatorTag: creatorTag ?? this.creatorTag,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      accentInfo: accentInfo ?? this.accentInfo,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      topicTag: topicTag ?? this.topicTag,
      rubySegments: rubySegments ?? this.rubySegments,
      subtitleCues: subtitleCues ?? this.subtitleCues,
      translation: translation ?? this.translation,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      streakDays: streakDays ?? this.streakDays,
      xp: xp ?? this.xp,
      isLiked: isLiked ?? this.isLiked,
      isFollowing: isFollowing ?? this.isFollowing,
      progress: progress ?? this.progress,
      isLightBackground: isLightBackground ?? this.isLightBackground,
    );
  }

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id'] as String? ?? '',
      backgroundImageUrl: json['backgroundImageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      creatorTag: json['creatorTag'] as String? ?? '',
      creatorAvatarUrl: json['creatorAvatarUrl'] as String? ?? '',
      accentInfo: json['accentInfo'] as String? ?? '',
      jlptLevel: json['jlptLevel'] as String? ?? '',
      topicTag: json['topicTag'] as String? ?? '',
      rubySegments:
          (json['rubySegments'] as List<dynamic>?)
              ?.map((e) => RubySegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translation: json['translation'] as String? ?? '',
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      streakDays: json['streakDays'] as int?,
      xp: json['xp'] as int?,
      isLiked: json['isLiked'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.4,
      isLightBackground: json['isLightBackground'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'backgroundImageUrl': backgroundImageUrl,
      'videoUrl': videoUrl,
      'creatorName': creatorName,
      'creatorTag': creatorTag,
      'creatorAvatarUrl': creatorAvatarUrl,
      'accentInfo': accentInfo,
      'jlptLevel': jlptLevel,
      'topicTag': topicTag,
      'rubySegments': rubySegments.map((e) => e.toJson()).toList(),
      'translation': translation,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'streakDays': streakDays,
      'xp': xp,
      'isLiked': isLiked,
      'isFollowing': isFollowing,
      'progress': progress,
      'isLightBackground': isLightBackground,
    };
  }
}
