import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/datasources/home_remote_datasource.dart';
import 'explore_video.dart';

/// Cách sắp xếp danh sách video ở màn Khám phá.
enum ExploreSort {
  relevance('Liên quan', 'relevance'),
  trending('Thịnh hành', 'viewCount,desc'),
  newest('Mới nhất', 'createdAt,desc');

  final String label;
  final String apiValue;
  const ExploreSort(this.label, this.apiValue);
}

/// Các trình độ lọc được, theo thứ tự từ dễ đến khó.
const List<String> exploreJlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

class ExploreService {
  static ExploreService? _instance;
  ExploreService._();
  static ExploreService get instance => _instance ??= ExploreService._();

  static const int pageSize = 20;

  final ApiClient _api = ApiClient.instance;
  final HomeRemoteDataSourceImpl _mapper = HomeRemoteDataSourceImpl();

  Future<ExplorePage> fetchVideos({
    required ExploreSort sort,
    String search = '',
    String? jlptLevel,
    Set<int> topicIds = const {},
    int page = 0,
  }) async {
    // Người xem (để biết đã lưu chưa) do server lấy từ access token.
    final query = <String, String>{
      'feed': 'for-you',
      'page': '$page',
      'size': '$pageSize',
      'sort': sort.apiValue,
      'jlptLevel': ?jlptLevel,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (topicIds.isNotEmpty) 'topicIds': topicIds.join(','),
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}/videos')
        .replace(queryParameters: query);

    final response = await _api.get(uri.toString());
    if (response is! Map<String, dynamic> || response['content'] is! List) {
      throw const FormatException('Backend trả về dữ liệu video không hợp lệ.');
    }

    final items = (response['content'] as List)
        .whereType<Map<String, dynamic>>()
        .map(_toExploreVideo)
        .whereType<ExploreVideo>()
        .toList();

    return ExplorePage(items: items, isLast: response['last'] != false);
  }

  /// Lưu / bỏ lưu video (POST / DELETE `/videos/{id}/saves`).
  Future<void> setSaved(int videoId, bool saved) async {
    final url = '${ApiConstants.baseUrl}/videos/$videoId/saves';
    if (saved) {
      await _api.post(url);
    } else {
      await _api.delete(url);
    }
  }

  ExploreVideo? _toExploreVideo(Map<String, dynamic> json) {
    final id = _toInt(json['id']);
    if (id == null) return null;

    final displayName = json['creatorDisplayName']?.toString().trim() ?? '';
    final username = json['creatorUsername']?.toString().trim() ?? '';
    final post = _mapper.toVideoPost(json);

    final thumbnailUrl = json['thumbnailUrl']?.toString().trim() ?? '';

    return ExploreVideo(
      id: id,
      title: json['title']?.toString().trim() ?? '',
      // Ưu tiên thumbnail thật; nếu không có thì dùng khung hình trích từ video.
      thumbnailUrl: thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : post.backgroundImageUrl,
      viewCount: _toInt(json['viewCount']) ?? 0,
      jlptLevel: json['jlptLevel']?.toString() ?? '',
      creatorName: displayName.isNotEmpty ? displayName : username,
      creatorAvatarUrl: json['creatorAvatarUrl']?.toString() ?? '',
      isSaved: json['isSaved'] == true,
      post: post,
    );
  }

  int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
