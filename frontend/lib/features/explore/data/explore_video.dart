import '../../home/domain/models/video_post.dart';

/// Một video trong lưới Khám phá. Tất cả các trường lấy từ VideoResponse
/// của backend; [post] dùng để mở trình phát video khi người dùng chạm vào.
class ExploreVideo {
  final int id;
  final String title;
  final String thumbnailUrl;
  final int viewCount;
  final String jlptLevel;
  final String creatorName;
  final String creatorAvatarUrl;
  final bool isSaved;
  final VideoPost post;

  const ExploreVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.jlptLevel,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.isSaved,
    required this.post,
  });

  ExploreVideo copyWith({bool? isSaved}) {
    return ExploreVideo(
      id: id,
      title: title,
      thumbnailUrl: thumbnailUrl,
      viewCount: viewCount,
      jlptLevel: jlptLevel,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
      isSaved: isSaved ?? this.isSaved,
      post: post,
    );
  }
}

class ExplorePage {
  final List<ExploreVideo> items;
  final bool isLast;

  const ExplorePage({required this.items, required this.isLast});
}
