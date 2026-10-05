import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import 'profile_storage.dart';

abstract class ProfileRemoteDataSource {
  Future<UserProfileModel> fetchProfile({int? userId});
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId});
  Future<List<TopicModel>> fetchTopics();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final String baseUrl;
  final http.Client _client;

  ProfileRemoteDataSourceImpl({
    this.baseUrl = 'http://localhost:8080',
    http.Client? client,
  }) : _client = client ?? http.Client();

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
      final response = await _client
          .get(Uri.parse('$baseUrl/api/v1/topics'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'] as List<dynamic>? ?? [];
        return data
            .map((item) => TopicModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Backend offline fallback
    }
    return _defaultTopics;
  }

  @override
  Future<UserProfileModel> fetchProfile({int? userId}) async {
    // 1. Try to fetch fresh state from Backend Spring Boot
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (userId != null) {
        headers['X-User-Id'] = userId.toString();
      }

      final response = await _client
          .get(Uri.parse('$baseUrl/api/v1/profile'), headers: headers)
          .timeout(const Duration(seconds: 2));

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

    // 2. If Backend is offline, retrieve persistent saved changes from browser localStorage
    final stored = _getFromStorage();
    if (stored != null) {
      return stored;
    }

    return _defaultProfile;
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId}) async {
    // 1. Save immediately to persistent browser storage so refresh never loses data
    _saveToStorage(profile);

    // 2. Synchronize to Backend Spring Boot REST API
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (userId != null) {
        headers['X-User-Id'] = userId.toString();
      }

      final payload = jsonEncode(profile.toUpdateJson());
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/v1/profile'),
            headers: headers,
            body: payload,
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonMap['data'] as Map<String, dynamic>;
        final updated = UserProfileModel.fromJson(data);
        _saveToStorage(updated);
        return updated;
      }
    } catch (_) {
      // Backend offline
    }

    return profile;
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
