export '../../../../core/utils/count_format.dart' show formatCount;

/// Một video hiển thị trong lưới của màn Profile (map từ `VideoResponse` của backend).
class ProfileVideo {
  final int id;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final int viewCount;
  final int likeCount;
  final String? jlptLevel;

  /// `PENDING` / `APPROVED` / `REJECTED` (chỉ có ý nghĩa với video của chính mình).
  final String? modStatus;
  final String? rejectionReason;

  /// JSON gốc từ backend: dùng để mở trình phát video (subtitle, người đăng...).
  final Map<String, dynamic> raw;

  const ProfileVideo({
    required this.id,
    required this.title,
    this.thumbnailUrl = '',
    this.videoUrl = '',
    this.viewCount = 0,
    this.likeCount = 0,
    this.jlptLevel,
    this.modStatus,
    this.rejectionReason,
    this.raw = const {},
  });

  bool get isPending => modStatus == 'PENDING';
  bool get isRejected => modStatus == 'REJECTED';

  factory ProfileVideo.fromJson(Map<String, dynamic> json) {
    int toInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    String? nonEmpty(Object? value) {
      final text = value?.toString() ?? '';
      return text.isEmpty ? null : text;
    }

    return ProfileVideo(
      id: toInt(json['id']),
      title: json['title']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      viewCount: toInt(json['viewCount']),
      likeCount: toInt(json['likeCount']),
      jlptLevel: nonEmpty(json['jlptLevel']),
      modStatus: nonEmpty(json['modStatus']),
      rejectionReason: nonEmpty(json['rejectionReason']),
      raw: json,
    );
  }
}

/// Số liệu trên trang hồ sơ (`GET /api/v1/profile/stats`).
class ProfileStats {
  final int followingCount;
  final int followerCount;
  final int likeCount;

  const ProfileStats({
    this.followingCount = 0,
    this.followerCount = 0,
    this.likeCount = 0,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    int toInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    return ProfileStats(
      followingCount: toInt(json['followingCount']),
      followerCount: toInt(json['followerCount']),
      likeCount: toInt(json['likeCount']),
    );
  }
}
