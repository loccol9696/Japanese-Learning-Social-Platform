import '../models/video_post.dart';

abstract class HomeRepository {
  Future<List<VideoPost>> getForYouFeed();
  Future<List<VideoPost>> getFollowingFeed();
  Future<bool> toggleLike(String postId);
  Future<bool> toggleSave(String postId);
  Future<bool> setFollow(int creatorId, {required bool follow});
}
