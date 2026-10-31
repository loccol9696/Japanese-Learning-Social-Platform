/// Thứ tự bình luận gốc; [apiValue] khớp enum CommentSort ở backend.
enum CommentSort {
  helpful('HELPFUL'),
  newest('NEWEST');

  final String apiValue;

  const CommentSort(this.apiValue);
}

/// Trạng thái đánh giá hữu ích mà backend trả về sau khi nhấn nút.
class CommentLikeResult {
  final bool isLiked;
  final int likeCount;

  const CommentLikeResult({required this.isLiked, required this.likeCount});

  factory CommentLikeResult.fromJson(Map<String, dynamic> json) {
    return CommentLikeResult(
      isLiked: json['isLiked'] == true,
      likeCount: VideoComment._toInt(json['likeCount']),
    );
  }
}

class VideoComment {
  final int id;
  final int videoId;
  final int? parentId;
  final int userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String content;
  final int likeCount;
  final bool isLiked;
  final DateTime? createdAt;
  final List<VideoComment> replies;

  const VideoComment({
    required this.id,
    required this.videoId,
    required this.parentId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    this.likeCount = 0,
    this.isLiked = false,
    required this.createdAt,
    required this.replies,
  });

  VideoComment copyWith({
    int? likeCount,
    bool? isLiked,
    List<VideoComment>? replies,
  }) {
    return VideoComment(
      id: id,
      videoId: videoId,
      parentId: parentId,
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      content: content,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
      replies: replies ?? this.replies,
    );
  }

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    return VideoComment(
      id: _toInt(json['id']),
      videoId: _toInt(json['videoId']),
      parentId: json['parentId'] == null ? null : _toInt(json['parentId']),
      userId: _toInt(json['userId']),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      likeCount: _toInt(json['likeCount']),
      isLiked: json['isLiked'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      replies: (json['replies'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VideoComment.fromJson)
          .toList(),
    );
  }

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
