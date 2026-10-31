import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Sửa / xoá video của chính người dùng. Server kiểm tra quyền sở hữu.
class VideoManageService {
  final ApiClient _api;

  VideoManageService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<void> update(
    int videoId, {
    required String title,
    String? description,
    required String jlptLevel,
    Set<int>? topicIds,
    List<String>? hashtags,
  }) async {
    await _api.patch(
      ApiConstants.videoDetailUrl('$videoId'),
      body: {
        'title': title,
        'description': description ?? '',
        'jlptLevel': jlptLevel,
        if (topicIds != null) 'topicIds': topicIds.toList(),
        'hashtags': ?hashtags,
      },
    );
  }

  /// Kiểm duyệt viên sửa chủ đề / hashtag; video giữ nguyên trạng thái duyệt.
  Future<void> updateClassification(
    int videoId, {
    required Set<int> topicIds,
    required List<String> hashtags,
  }) async {
    await _api.patch(
      ApiConstants.videoClassificationUrl(videoId),
      body: {'topicIds': topicIds.toList(), 'hashtags': hashtags},
    );
  }

  Future<void> delete(int videoId) async {
    await _api.delete(ApiConstants.videoDetailUrl('$videoId'));
  }
}
