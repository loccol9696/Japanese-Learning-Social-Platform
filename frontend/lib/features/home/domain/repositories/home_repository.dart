import '../models/video_post.dart';

abstract class HomeRepository {
  Future<List<VideoPost>> getForYouFeed();
  Future<List<VideoPost>> getFollowingFeed();
  Future<bool> setLiked(String postId, {required bool liked});
  Future<bool> setSaved(String postId, {required bool saved});
  Future<bool> setFollow(int creatorId, {required bool follow});
}
