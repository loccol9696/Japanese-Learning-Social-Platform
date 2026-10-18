import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import 'profile_storage.dart';

abstract class ProfileRemoteDataSource {
  Future<UserProfileModel> fetchProfile();
  Future<UserProfileModel> updateProfile(UserProfileModel profile);
  Future<List<TopicModel>> fetchTopics();
}

/// Hồ sơ của người dùng đang đăng nhập: `GET/PUT /api/v1/profile` (backend xác định
/// người dùng bằng JWT). Chỉ gọi API khi đã đăng nhập. Backend chưa lưu
/// topics/interests của người dùng nên hai trường này được giữ ở bộ nhớ cục bộ.
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _api;
  final Future<Map<String, dynamic>?> Function() _currentUser;

  ProfileRemoteDataSourceImpl({
    ApiClient? apiClient,
    Future<Map<String, dynamic>?> Function()? currentUser,
  })  : _api = apiClient ?? ApiClient.instance,
        _currentUser = currentUser ?? TokenStorage.instance.getUserData;

  static const Duration _timeout = Duration(seconds: 3);

  static const String _storageKey = 'jlsp_user_profile_data';

  static const UserProfileModel _defaultProfile = UserProfileModel(
    id: 1,
    username: 'nihongo_pro',
    email: 'learner@jlsp.com',
    displayName: 'Sakura Learner',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    currentLevel: 'N3',
    bio: 'Konnichiwa! Đang học N3 để chuẩn bị du học Tokyo vào mùa xuân.',
    interests: ['Anime & Manga', 'Giao tiếp hằng ngày', 'Luyện thi JLPT'],
    topics: [
      TopicModel(id: 1, name: 'Anime & Manga'),
      TopicModel(id: 2, name: 'Giao tiếp hằng ngày'),
      TopicModel(id: 3, name: 'Luyện thi JLPT'),
    ],
  );

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

  @override
  Future<List<TopicModel>> fetchTopics() async {
    try {
      final data = await _api.get(ApiConstants.topicsUrl, timeout: _timeout);
      if (data is List && data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(TopicModel.fromJson)
            .toList();
      }
    } on ApiException {
      // Backend offline / lỗi -> danh sách mặc định
    }
    return _defaultTopics;
  }

  @override
  Future<UserProfileModel> fetchProfile() async {
    final local = _getFromStorage();
    if (await _isLoggedIn()) {
      try {
        final data = await _api.get(ApiConstants.profileUrl, timeout: _timeout);
        if (data is Map<String, dynamic>) {
          final profile = _withLocalOnlyFields(UserProfileModel.fromJson(data), local);
          _saveToStorage(profile);
          return profile;
        }
      } on ApiException {
        // Backend offline / lỗi -> dùng bản lưu cục bộ
      }
    }
    return local ?? _defaultProfile;
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel profile) async {
    // Lưu cục bộ ngay để không mất dữ liệu khi backend lỗi
    _saveToStorage(profile);

    if (!await _isLoggedIn()) {
      return profile;
    }
    try {
      final data = await _api.put(
        ApiConstants.profileUrl,
        body: profile.toUpdateJson(),
        timeout: _timeout,
      );
      if (data is Map<String, dynamic>) {
        final updated = _withLocalOnlyFields(UserProfileModel.fromJson(data), profile);
        _saveToStorage(updated);
        return updated;
      }
    } on ApiException {
      // Backend offline
    }
    return profile;
  }

  Future<bool> _isLoggedIn() async => (await _currentUser()) != null;

  UserProfileModel _withLocalOnlyFields(UserProfileModel server, UserProfileModel? local) {
    if (local == null) return server;
    return server.copyWith(topics: local.topics, interests: local.interests);
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
