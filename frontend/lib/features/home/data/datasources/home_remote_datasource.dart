import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/video_post.dart';
import '../mappers/video_post_mapper.dart';

abstract class HomeRemoteDataSource {
  Future<List<VideoPost>> fetchForYouFeed();
  Future<List<VideoPost>> fetchFollowingFeed();

  /// Thích (`POST`) / bỏ thích (`DELETE`) video; idempotent ở backend.
  Future<void> setLiked(String videoId, bool liked);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  HomeRemoteDataSourceImpl({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  @override
  Future<List<VideoPost>> fetchForYouFeed() {
    return _fetchFeed('for-you');
  }

  @override
  Future<List<VideoPost>> fetchFollowingFeed() {
    return _fetchFeed('following');
  }

  @override
  Future<void> setLiked(String videoId, bool liked) async {
    final url = ApiConstants.videoLikesUrl(videoId);
    if (liked) {
      await _apiClient.post(url, withAuth: true);
    } else {
      await _apiClient.delete(url);
    }
  }

  Future<List<VideoPost>> _fetchFeed(String feed) async {
    final response = await _apiClient.get(
      '${ApiConstants.baseUrl}/videos?feed=$feed&size=20',
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về dữ liệu video không hợp lệ.');
    }

    final content = response['content'];
    if (content is! List) {
      throw const FormatException(
        'Backend không trả về danh sách video trong feed.',
      );
    }

    return content.whereType<Map<String, dynamic>>().map(videoPostFromJson).toList();
  }
}
