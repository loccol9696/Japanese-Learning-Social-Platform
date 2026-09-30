import '../../domain/models/video_post.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<VideoPost>> getForYouFeed() {
    return remoteDataSource.fetchForYouFeed();
  }

  @override
  Future<List<VideoPost>> getFollowingFeed() {
    return remoteDataSource.fetchFollowingFeed();
  }

  @override
  Future<bool> toggleLike(String postId) async {
    // In real app, call API
    return true;
  }

  @override
  Future<bool> toggleFollow(String creatorId) async {
    // In real app, call API
    return true;
  }
}
