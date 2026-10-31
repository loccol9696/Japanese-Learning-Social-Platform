import 'ruby_segment.dart';

class VideoPost {
  final String id;
  final String backgroundImageUrl;
  final String videoUrl;
  final String creatorName;
  /// Id tài khoản người đăng (null nếu server không trả về).
  final int? creatorId;
  final String creatorTag;
  final String creatorAvatarUrl;
  final String accentInfo;
  final String jlptLevel;
  final String topicTag;
  final String audioTitle;
  final String audioDiscImageUrl;
  final List<RubySegment> rubySegments;
  final List<SubtitleCue> subtitleCues;
  final String translation;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int streakDays;
  final int xp;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;
  final double progress;
  final bool isLightBackground;

  const VideoPost({
    required this.id,
    required this.backgroundImageUrl,
    this.videoUrl = '',
    required this.creatorName,
    this.creatorId,

    required this.creatorTag,
    required this.creatorAvatarUrl,
    required this.accentInfo,
    required this.jlptLevel,
    required this.topicTag,
    required this.audioTitle,
    required this.audioDiscImageUrl,
    required this.rubySegments,
    this.subtitleCues = const [],
    required this.translation,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.streakDays = 0,
    this.xp = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowing = false,
    this.progress = 0.4,
    this.isLightBackground = false,
  });

  VideoPost copyWith({
    String? id,
    String? backgroundImageUrl,
    String? videoUrl,
    String? creatorName,
    int? creatorId,
    String? creatorTag,
    String? creatorAvatarUrl,
    String? accentInfo,
    String? jlptLevel,
    String? topicTag,
    String? audioTitle,
    String? audioDiscImageUrl,
    List<RubySegment>? rubySegments,
    List<SubtitleCue>? subtitleCues,
    String? translation,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? streakDays,
    int? xp,
    bool? isLiked,
    bool? isSaved,
    bool? isFollowing,
    double? progress,
    bool? isLightBackground,
  }) {
    return VideoPost(
      id: id ?? this.id,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      creatorName: creatorName ?? this.creatorName,
      creatorId: creatorId ?? this.creatorId,
      creatorTag: creatorTag ?? this.creatorTag,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      accentInfo: accentInfo ?? this.accentInfo,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      topicTag: topicTag ?? this.topicTag,
      audioTitle: audioTitle ?? this.audioTitle,
      audioDiscImageUrl: audioDiscImageUrl ?? this.audioDiscImageUrl,
      rubySegments: rubySegments ?? this.rubySegments,
      subtitleCues: subtitleCues ?? this.subtitleCues,
      translation: translation ?? this.translation,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      streakDays: streakDays ?? this.streakDays,
      xp: xp ?? this.xp,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
      creatorId: (json['creatorId'] as num?)?.toInt(),
      creatorName: json['creatorName'] as String? ?? '',
      creatorTag: json['creatorTag'] as String? ?? '',
      creatorAvatarUrl: json['creatorAvatarUrl'] as String? ?? '',
      accentInfo: json['accentInfo'] as String? ?? '',
      jlptLevel: json['jlptLevel'] as String? ?? '',
      topicTag: json['topicTag'] as String? ?? '',
      audioTitle: json['audioTitle'] as String? ?? '',
      audioDiscImageUrl: json['audioDiscImageUrl'] as String? ?? '',
      rubySegments:
          (json['rubySegments'] as List<dynamic>?)
              ?.map((e) => RubySegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translation: json['translation'] as String? ?? '',
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
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
      'creatorId': creatorId,
      'creatorTag': creatorTag,
      'creatorAvatarUrl': creatorAvatarUrl,
      'accentInfo': accentInfo,
      'jlptLevel': jlptLevel,
      'topicTag': topicTag,
      'audioTitle': audioTitle,
      'audioDiscImageUrl': audioDiscImageUrl,
      'rubySegments': rubySegments.map((e) => e.toJson()).toList(),
      'translation': translation,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'streakDays': streakDays,
      'xp': xp,
      'isLiked': isLiked,
      'isFollowing': isFollowing,
      'progress': progress,
      'isLightBackground': isLightBackground,
    };
  }
}
