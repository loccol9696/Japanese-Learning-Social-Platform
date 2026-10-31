class VideoComment {
  final int id;
  final int videoId;
  final int? parentId;

  /// Tên người được trả lời (null với bình luận gốc).
  final String? replyToName;
  final int? replyToUserId;
  final int userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String content;
  final DateTime? createdAt;
  final List<VideoComment> replies;

  const VideoComment({
    required this.id,
    required this.videoId,
    required this.parentId,
    this.replyToName,
    this.replyToUserId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
    required this.replies,
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    return VideoComment(
      id: _toInt(json['id']),
      videoId: _toInt(json['videoId']),
      parentId: json['parentId'] == null ? null : _toInt(json['parentId']),
      replyToName: json['replyToName']?.toString(),
      replyToUserId: json['replyToUserId'] == null
          ? null
          : _toInt(json['replyToUserId']),
      userId: _toInt(json['userId']),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
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
