import '../models/video_post.dart';

abstract class HomeRepository {
  Future<List<VideoPost>> getForYouFeed();
  Future<List<VideoPost>> getFollowingFeed();
  Future<void> setLiked(String postId, bool liked);
  Future<bool> toggleFollow(String creatorId);
}
