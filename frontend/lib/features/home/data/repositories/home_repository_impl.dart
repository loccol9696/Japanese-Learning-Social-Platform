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
    return remoteDataSource.toggleLike(postId);
  }

  @override
  Future<bool> toggleSave(String postId) {
    return remoteDataSource.toggleSave(postId);
  }

  @override
  Future<bool> setFollow(int creatorId, {required bool follow}) {
    return remoteDataSource.setFollow(creatorId, follow: follow);
  }
}
