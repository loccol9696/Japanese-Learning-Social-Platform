import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/datasources/home_remote_datasource.dart';
import 'explore_video.dart';

/// Bộ lọc của màn Khám phá — mỗi lựa chọn tương ứng 1 tham số thật của
/// API `GET /videos` (sắp xếp hoặc jlptLevel), riêng [users] chuyển ô tìm kiếm sang tìm
/// người dùng (`GET /users/search`) và không dùng cho danh sách video.
enum ExploreFilter {
  trending('Thịnh hành'),
  newest('Mới nhất'),
  users('Người dùng'),
  n5('JLPT N5'),
  n4('JLPT N4'),
  n3('JLPT N3'),
  n2('JLPT N2'),
  n1('JLPT N1');

  final String label;
  const ExploreFilter(this.label);

  bool get isUsers => this == ExploreFilter.users;

  String get sort =>
      this == ExploreFilter.trending ? 'viewCount,desc' : 'createdAt,desc';

  String? get jlptLevel => switch (this) {
    ExploreFilter.n5 => 'N5',
    ExploreFilter.n4 => 'N4',
    ExploreFilter.n3 => 'N3',
    ExploreFilter.n2 => 'N2',
    ExploreFilter.n1 => 'N1',
    _ => null,
  };
}

class ExploreService {
  static ExploreService? _instance;
  ExploreService._();
  static ExploreService get instance => _instance ??= ExploreService._();

  static const int pageSize = 20;

  final ApiClient _api = ApiClient.instance;
  final HomeRemoteDataSourceImpl _mapper = HomeRemoteDataSourceImpl();

  Future<ExplorePage> fetchVideos({
    required ExploreFilter filter,
    String search = '',
    int? topicId,
    int page = 0,
  }) async {
    // Người xem (để biết đã lưu chưa) do server lấy từ access token.
    final query = <String, String>{
      'feed': 'for-you',
      'page': '$page',
      'size': '$pageSize',
      'sort': filter.sort,
      if (filter.jlptLevel != null) 'jlptLevel': filter.jlptLevel!,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      // Server bỏ qua chủ đề khi có từ khoá tìm kiếm.
      if (topicId != null) 'topicId': '$topicId',
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
