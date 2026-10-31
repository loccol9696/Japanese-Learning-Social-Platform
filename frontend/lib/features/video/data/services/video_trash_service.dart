import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/user_video_model.dart';

/// Thùng rác video: xóa mềm, khôi phục và xóa hẳn.
class VideoTrashService {
  final ApiClient _apiClient;

  VideoTrashService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  Future<void> moveToTrash(int videoId) async {
    await _apiClient.delete(ApiConstants.videoUrl(videoId));
  }

  Future<List<UserVideoModel>> fetchTrash() async {
    final response = await _apiClient.get(
      '${ApiConstants.videoTrashUrl}?size=100',
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về thùng rác không hợp lệ.');
    }
    return (response['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserVideoModel.fromJson)
        .toList();
  }

  Future<void> restore(int videoId) async {
    await _apiClient.post(ApiConstants.restoreVideoUrl(videoId));
  }

  Future<void> deletePermanently(int videoId) async {
    await _apiClient.delete(ApiConstants.permanentDeleteVideoUrl(videoId));
  }
}
