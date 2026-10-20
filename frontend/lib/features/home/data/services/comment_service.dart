import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/video_comment.dart';

class CommentService {
  final ApiClient _apiClient;

  CommentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  Future<List<VideoComment>> fetchComments(String videoId) async {
    final response = await _apiClient.get(
      '${ApiConstants.baseUrl}/videos/$videoId/comments',
      withAuth: false,
    );
    if (response is! List) {
      throw const FormatException(
        'Backend trả về danh sách bình luận không hợp lệ.',
      );
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(VideoComment.fromJson)
        .toList();
  }

  Future<VideoComment> createComment(
    String videoId,
    String content, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parentId'] = parentId;
    final response = await _apiClient.post(
      '${ApiConstants.baseUrl}/videos/$videoId/comments',
      body: body,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về bình luận không hợp lệ.');
    }
    return VideoComment.fromJson(response);
  }

  Future<void> deleteComment(String videoId, int commentId) async {
    await _apiClient.delete(
      '${ApiConstants.baseUrl}/videos/$videoId/comments/$commentId',
    );
  }
}
