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
  Future<void> setLiked(String postId, bool liked) {
    return remoteDataSource.setLiked(postId, liked);
  }

  @override
  Future<bool> toggleFollow(String creatorId) async {
    // TODO: backend chưa có API theo dõi (bảng follows đã có) -> chỉ đổi trạng thái trên UI
    return true;
  }
}
