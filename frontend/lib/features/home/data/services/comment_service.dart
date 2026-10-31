import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/video_comment.dart';

class CommentService {
  final ApiClient _apiClient;

  CommentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  /// Gửi kèm token nếu đã đăng nhập để backend trả đúng isLiked; khách vẫn xem
  /// được vì đây là API công khai.
  Future<List<VideoComment>> fetchComments(
    String videoId, {
    CommentSort sort = CommentSort.helpful,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.baseUrl}/videos/$videoId/comments?sort=${sort.apiValue}',
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
    int? replyToId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parentId'] = parentId;
    if (replyToId != null) body['replyToId'] = replyToId;
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

  Future<CommentLikeResult> likeComment(String videoId, int commentId) async {
    return _parseLikeResult(
      await _apiClient.post(_likesUrl(videoId, commentId)),
    );
  }

  Future<CommentLikeResult> unlikeComment(String videoId, int commentId) async {
    return _parseLikeResult(
      await _apiClient.delete(_likesUrl(videoId, commentId)),
    );
  }

  String _likesUrl(String videoId, int commentId) =>
      '${ApiConstants.baseUrl}/videos/$videoId/comments/$commentId/likes';

  CommentLikeResult _parseLikeResult(dynamic response) {
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về lượt đánh giá không hợp lệ.');
    }
    return CommentLikeResult.fromJson(response);
  }
}
