import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/datasources/home_remote_datasource.dart';
import '../../home/domain/models/video_post.dart';
import '../domain/models/public_profile_model.dart';

/// Xem hồ sơ công khai của người khác, video của họ và theo dõi / bỏ theo dõi.
class PublicProfileService {
  PublicProfileService({ApiClient? api, HomeRemoteDataSourceImpl? videoMapper})
    : _api = api ?? ApiClient.instance,
      _videoMapper = videoMapper ?? HomeRemoteDataSourceImpl(apiClient: api);

  static final PublicProfileService instance = PublicProfileService();

  final ApiClient _api;
  final HomeRemoteDataSourceImpl _videoMapper;

  Future<PublicProfile> getProfile(int userId) async {
    final res = await _api.get(
      '${ApiConstants.baseUrl}/users/$userId/public-profile',
      withAuth: false,
    );
    return PublicProfile.fromJson(res as Map<String, dynamic>);
  }

  /// Video công khai của người dùng, dạng dùng được ngay trong trình phát.
  Future<List<VideoPost>> getVideos(int userId) async {
    final res = await _api.get(
      '${ApiConstants.baseUrl}/users/$userId/videos?size=30',
      withAuth: false,
    );
    final content = res is Map ? res['content'] : null;
    if (content is! List) return const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map(_videoMapper.toVideoPost)
        .toList();
  }

  /// Trả về true nếu sau khi bấm là đang theo dõi.
  Future<({bool following, int followersCount})> toggleFollow(int userId) async {
    final res = await _api.post('${ApiConstants.baseUrl}/users/$userId/follow');
    final map = res as Map<String, dynamic>;
    return (
      following: map['following'] == true,
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
    );
  }
}
