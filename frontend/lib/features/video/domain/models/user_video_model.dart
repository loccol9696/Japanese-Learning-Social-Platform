class UserVideoModel {
  final int id;
  final int? userId;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int duration;
  final String jlptLevel;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final String status;
  final String modStatus;
  final String? rejectionReason;
  final String? createdAt;
  final String? reviewedAt;
  final String? userDisplayName;
  final String? username;
  final String? userAvatarUrl;

  const UserVideoModel({
    required this.id,
    this.userId,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration = 0,
    this.jlptLevel = 'N5',
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    this.status = 'PUBLIC',
    this.modStatus = 'PENDING',
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
    this.userDisplayName,
    this.username,
    this.userAvatarUrl,
  });

  bool get isDraft => status.toUpperCase() == 'DRAFT' || modStatus.toUpperCase() == 'DRAFT';
  bool get isPending => !isDraft && modStatus.toUpperCase() == 'PENDING';
  bool get isApproved => !isDraft && modStatus.toUpperCase() == 'APPROVED';
  bool get isRejected => !isDraft && modStatus.toUpperCase() == 'REJECTED';
  bool get isPublic => status.toUpperCase() == 'PUBLIC';

  factory UserVideoModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return UserVideoModel(
      id: parseInt(json['id']),
      userId: json['userId'] != null ? parseInt(json['userId']) : null,
      title: json['title'] as String? ?? 'Bài học không tên',
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: parseInt(json['duration']),
      jlptLevel: json['jlptLevel'] as String? ?? 'N5',
      viewCount: parseInt(json['viewCount'] ?? json['viewsCount']),
      likeCount: parseInt(json['likeCount'] ?? json['likesCount']),
      commentCount: parseInt(json['commentCount'] ?? json['commentsCount']),
      saveCount: parseInt(json['saveCount'] ?? json['savesCount']),
      status: json['status'] as String? ?? 'PUBLIC',
      modStatus: json['modStatus'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] as String?,
      reviewedAt: json['reviewedAt'] as String?,
      userDisplayName: json['userDisplayName'] as String?,
      username: json['username'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'jlptLevel': jlptLevel,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'status': status,
      'modStatus': modStatus,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'reviewedAt': reviewedAt,
      'userDisplayName': userDisplayName,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
    };
  }
}
