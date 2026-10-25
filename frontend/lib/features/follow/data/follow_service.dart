import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'follow_models.dart';

/// Gọi REST API quản lý theo dõi.
class FollowService {
  FollowService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// Những người đang theo dõi mình.
  Future<List<FollowUser>> fetchFollowers() async {
    final data = await _api.get(ApiConstants.myFollowersUrl);
    return _list(data).map(FollowUser.fromJson).toList();
  }

  /// Những người mình đang theo dõi.
  Future<List<FollowUser>> fetchFollowing() async {
    final data = await _api.get(ApiConstants.myFollowingUrl);
    return _list(data).map(FollowUser.fromJson).toList();
  }

  Future<void> follow(int userId) async {
    await _api.post(ApiConstants.followUrl(userId));
  }

  Future<void> unfollow(int userId) async {
    await _api.delete(ApiConstants.followUrl(userId));
  }

  Future<PublicProfile> fetchPublicProfile(int userId) async {
    final data = await _api.get(ApiConstants.publicProfileUrl(userId));
    if (data is Map<String, dynamic>) return PublicProfile.fromJson(data);
    throw const FormatException('Backend trả về hồ sơ không hợp lệ.');
  }

  static List<Map<String, dynamic>> _list(dynamic data) =>
      data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];
}
