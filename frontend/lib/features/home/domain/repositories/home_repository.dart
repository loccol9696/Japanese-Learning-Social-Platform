import '../models/video_post.dart';

abstract class HomeRepository {
  Future<List<VideoPost>> getForYouFeed();
  Future<List<VideoPost>> getFollowingFeed();
  Future<bool> toggleLike(String postId);
  Future<bool> toggleFollow(String creatorId);
}
