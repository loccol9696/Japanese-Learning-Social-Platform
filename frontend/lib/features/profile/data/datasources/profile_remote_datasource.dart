import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../video/domain/models/user_video_model.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import 'profile_storage.dart';

abstract class ProfileRemoteDataSource {
  Future<UserProfileModel> fetchProfile({int? userId});
  Future<UserProfileModel> updateProfile(
    UserProfileModel profile, {
    int? userId,
  });
  Future<List<TopicModel>> fetchTopics();
  Future<List<UserVideoModel>> fetchUserVideos({int? userId});
  Future<List<UserVideoModel>> fetchMyVideosStatus();
  Future<List<UserVideoModel>> fetchLikedVideos();
  Future<List<UserVideoModel>> fetchSavedVideos();
  Future<List<UserVideoModel>> fetchModerationVideos({
    String status = 'PENDING',
  });
  Future<void> approveVideo(int videoId);
  Future<void> rejectVideo(int videoId, String reason);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final String baseUrl;
  final http.Client _client;

  ProfileRemoteDataSourceImpl({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConstants.baseUrl,
      _client = client ?? http.Client();

  static const String _storageKey = 'jlsp_user_profile_data';

  static const List<TopicModel> _defaultTopics = [
    TopicModel(id: 1, name: 'Anime & Manga'),
    TopicModel(id: 2, name: 'Giao tiếp hằng ngày'),
    TopicModel(id: 3, name: 'Luyện thi JLPT'),
    TopicModel(id: 4, name: 'Văn hóa & Du lịch'),
    TopicModel(id: 5, name: 'Âm nhạc J-Pop'),
    TopicModel(id: 6, name: 'Ẩm thực Nhật Bản'),
    TopicModel(id: 7, name: 'Kanji & Hán tự'),
    TopicModel(id: 8, name: 'Công việc & IT'),
    TopicModel(id: 9, name: 'Tin tức thời sự'),
  ];

  String _buildUrl(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (baseUrl.endsWith('/api/v1')) {
      return '$baseUrl/$cleanPath';
    }
    return '$baseUrl/api/v1/$cleanPath';
  }

  @override
  Future<List<TopicModel>> fetchTopics() async {
    try {
      final topicsUrl = _buildUrl('topics');
      final response = await _client
          .get(Uri.parse(topicsUrl))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'] as List<dynamic>? ?? [];
        if (data.isNotEmpty) {
          return data
              .map((item) => TopicModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Backend offline fallback
    }
    return _defaultTopics;
  }

  @override
  Future<UserProfileModel> fetchProfile({int? userId}) async {
    // 1. Try to fetch fresh state from Backend Spring Boot
    // Hồ sơ của chính người đang đăng nhập — server xác định qua access token.
    try {
      final profileUrl = _buildUrl('profile');
      final response = await _authorized(
        (headers) => _client.get(Uri.parse(profileUrl), headers: headers),
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'] as Map<String, dynamic>;
        final profile = UserProfileModel.fromJson(data);
        _saveToStorage(profile);
        return profile;
      }
    } catch (_) {
      // Backend offline or connection refused
    }

    // 2. If Backend is offline, retrieve persistent saved changes from storage
    final stored = _getFromStorage();
    if (stored != null) {
      return stored;
    }

    return const UserProfileModel();
  }

  @override
  Future<UserProfileModel> updateProfile(
    UserProfileModel profile, {
    int? userId,
  }) async {
    final userData = await TokenStorage.instance.getUserData();
    final profileUrl = _buildUrl('profile');
    final response = await _authorized(
      (headers) => _client.put(
        Uri.parse(profileUrl),
        headers: headers,
        body: jsonEncode(profile.toUpdateJson()),
      ),
    );
    final data = ApiClient.decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu hồ sơ trả về không hợp lệ.');
    }

    final updated = UserProfileModel.fromJson(data);
    _saveToStorage(updated);

    // Cập nhật lại TokenStorage để giao diện toàn app phản ánh ngay.
    if (userData != null) {
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['displayName'] = updated.displayName;
      updatedUserData['avatarUrl'] = updated.avatarUrl;
      await TokenStorage.instance.saveUser(updatedUserData);
    }

    return updated;
  }

  /// Gửi request qua [ApiClient]: tự gắn access token, tự làm mới khi hết hạn,
  /// phiên hỏng thì đưa người dùng về màn Đăng nhập.
  Future<http.Response> _authorized(RequestSender send) =>
      ApiClient.instance.send(send, timeout: const Duration(seconds: 6));

  @override
  Future<List<UserVideoModel>> fetchUserVideos({int? userId}) async {
    try {
      // ID chỉ dùng để chọn trang hồ sơ cần xem, không dùng để xác thực.
      final ownerId = userId ?? await TokenStorage.instance.getUserId();
      if (ownerId == null) return [];
      final url = ApiConstants.userVideosUrl(ownerId);
      final response = await _authorized(
        (headers) => _client.get(Uri.parse(url), headers: headers),
      );
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'];
        final List<dynamic> list = data is Map<String, dynamic>
            ? (data['content'] as List<dynamic>? ?? [])
            : (data is List<dynamic> ? data : []);
        return list
            .map(
              (item) => UserVideoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<UserVideoModel>> fetchMyVideosStatus() async {
    try {
      final url = ApiConstants.myVideosStatusUrl;
      final response = await _authorized(
        (headers) => _client.get(Uri.parse(url), headers: headers),
      );
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'];
        final List<dynamic> list = data is Map<String, dynamic>
            ? (data['content'] as List<dynamic>? ?? [])
            : (data is List<dynamic> ? data : []);
        return list
            .map(
              (item) => UserVideoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<UserVideoModel>> _fetchCollection(String path) async {
    try {
      final url = '${ApiConstants.baseUrl}/videos/$path?size=30';
      final response = await _authorized(
        (headers) => _client.get(Uri.parse(url), headers: headers),
      );
      if (response.statusCode == 200) {
        final data =
            (jsonDecode(response.body) as Map<String, dynamic>)['data'];
        final list = data is Map<String, dynamic>
            ? (data['content'] as List<dynamic>? ?? [])
            : <dynamic>[];
        return list
            .map(
              (item) => UserVideoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<UserVideoModel>> fetchLikedVideos() => _fetchCollection('liked');

  @override
  Future<List<UserVideoModel>> fetchSavedVideos() => _fetchCollection('saved');

  @override
  Future<List<UserVideoModel>> fetchModerationVideos({
    String status = 'PENDING',
  }) async {
    try {
      final url = '${ApiConstants.moderationVideosUrl}?status=$status';
      final response = await _authorized(
        (headers) => _client.get(Uri.parse(url), headers: headers),
      );
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'];
        final List<dynamic> list = data is Map<String, dynamic>
            ? (data['content'] as List<dynamic>? ?? [])
            : (data is List<dynamic> ? data : []);
        return list
            .map(
              (item) => UserVideoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<void> approveVideo(int videoId) async {
    final url = ApiConstants.approveVideoUrl(videoId);
    final response = await _authorized(
      (headers) => _client.post(Uri.parse(url), headers: headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message'] ?? 'Phê duyệt video thất bại');
    }
  }

  @override
  Future<void> rejectVideo(int videoId, String reason) async {
    final url = ApiConstants.rejectVideoUrl(videoId);
    final body = jsonEncode({'reason': reason});
    final response = await _authorized(
      (headers) => _client.post(Uri.parse(url), headers: headers, body: body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message'] ?? 'Từ chối duyệt video thất bại');
    }
  }

  void _saveToStorage(UserProfileModel profile) {
    try {
      final raw = jsonEncode(profile.toJson());
      ProfileStorage.save(_storageKey, raw);
    } catch (_) {}
  }

  UserProfileModel? _getFromStorage() {
    try {
      final raw = ProfileStorage.get(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return UserProfileModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }
}
