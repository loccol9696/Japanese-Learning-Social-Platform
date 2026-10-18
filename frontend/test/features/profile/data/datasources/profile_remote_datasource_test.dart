import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response ok(Map<String, dynamic> data) => http.Response.bytes(
        utf8.encode(jsonEncode({'status': 200, 'data': data})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  const serverUser = {
    'id': 42,
    'username': 'alice',
    'email': 'alice@jlsp.com',
    'displayName': 'Alice',
    'avatarUrl': 'https://cdn/a.png',
    'jlptLevel': 'N3',
    'bio': 'Xin chào',
  };

  ProfileRemoteDataSourceImpl dataSource(
    MockClient client, {
    Map<String, dynamic>? currentUser = const {'id': 42},
  }) {
    return ProfileRemoteDataSourceImpl(
      apiClient: ApiClient.withClient(client, tokenProvider: () async => 'jwt'),
      currentUser: () async => currentUser,
    );
  }

  test('fetchProfile reads the logged-in user from /profile (JWT, no user id in URL)', () async {
    late http.Request sent;
    final ds = dataSource(MockClient((request) async {
      sent = request;
      return ok(serverUser);
    }));

    final profile = await ds.fetchProfile();

    expect(sent.method, 'GET');
    expect(sent.url.path, '/api/v1/profile');
    expect(sent.headers['Authorization'], 'Bearer jwt');
    expect(sent.headers.containsKey('X-User-Id'), isFalse);
    expect(profile.displayName, 'Alice');
    expect(profile.currentLevel, 'N3');
  });

  test('updateProfile PUTs to /profile and keeps local-only interests', () async {
    late http.Request sent;
    final ds = dataSource(MockClient((request) async {
      sent = request;
      return ok({...serverUser, 'displayName': 'Alice 2'});
    }));

    const edited = UserProfileModel(
      id: 42,
      username: 'alice',
      email: 'alice@jlsp.com',
      displayName: 'Alice 2',
      avatarUrl: 'https://cdn/a.png',
      currentLevel: 'N3',
      bio: 'Xin chào',
      topics: [TopicModel(id: 1, name: 'Anime & Manga')],
      interests: ['Anime & Manga'],
    );

    final saved = await ds.updateProfile(edited);

    expect(sent.method, 'PUT');
    expect(sent.url.path, '/api/v1/profile');
    expect(jsonDecode(sent.body)['displayName'], 'Alice 2');
    expect(saved.displayName, 'Alice 2');
    // Backend chưa lưu interests -> không được làm mất lựa chọn của người dùng
    expect(saved.interests, ['Anime & Manga']);
  });

  test('without a logged-in user no request is sent', () async {
    var calls = 0;
    final ds = dataSource(
      MockClient((_) async {
        calls++;
        return ok(serverUser);
      }),
      currentUser: null,
    );

    final profile = await ds.fetchProfile();

    expect(calls, 0);
    expect(profile, isA<UserProfileModel>());
  });

  test('backend failure falls back instead of throwing', () async {
    final ds = dataSource(MockClient((_) async => http.Response('', 503)));

    final profile = await ds.fetchProfile();

    expect(profile, isA<UserProfileModel>());
  });

  test('fetchTopics reads /topics and falls back to defaults on failure', () async {
    http.Response okList(List<Map<String, dynamic>> data) => http.Response.bytes(
          utf8.encode(jsonEncode({'status': 200, 'data': data})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    final ds = dataSource(MockClient((request) async {
      expect(request.url.path, '/api/v1/topics');
      return okList([
        {'id': 7, 'name': 'Kanji & Hán tự'},
      ]);
    }));
    final topics = await ds.fetchTopics();
    expect(topics.map((t) => t.name), ['Kanji & Hán tự']);

    final offline = dataSource(MockClient((_) async => http.Response('', 503)));
    expect(await offline.fetchTopics(), isNotEmpty);
  });

  test('fetchStats reads /profile/stats', () async {
    late http.Request sent;
    final ds = dataSource(MockClient((request) async {
      sent = request;
      return ok({'followingCount': 3, 'followerCount': 120, 'likeCount': 4567});
    }));

    final stats = await ds.fetchStats();

    expect(sent.url.path, '/api/v1/profile/stats');
    expect(stats.followerCount, 120);
    expect(stats.likeCount, 4567);
  });

  test('video lists read PageResponse.content from the right endpoints', () async {
    final paths = <String>[];
    final ds = dataSource(MockClient((request) async {
      paths.add(request.url.path);
      return ok({
        'content': [
          {'id': 5, 'title': 'Kính ngữ', 'thumbnailUrl': 'https://cdn/t.jpg', 'viewCount': 1203,
           'likeCount': 9, 'jlptLevel': 'N3', 'modStatus': 'PENDING'},
        ],
        'page': 0, 'size': 30, 'totalElements': 1, 'totalPages': 1, 'last': true,
      });
    }));

    final mine = await ds.fetchMyVideos();
    await ds.fetchSavedVideos();
    await ds.fetchLikedVideos();

    expect(paths, ['/api/v1/videos/my-status', '/api/v1/profile/saved-videos', '/api/v1/profile/liked-videos']);
    expect(mine.single.title, 'Kính ngữ');
    expect(mine.single.viewCount, 1203);
    expect(mine.single.isPending, isTrue);
  });

  test('video list failure is surfaced, not replaced with sample data', () async {
    final ds = dataSource(MockClient((_) async => http.Response('', 503)));

    expect(ds.fetchSavedVideos(), throwsA(isA<ApiException>()));
    expect(ds.fetchStats(), throwsA(isA<ApiException>()));
  });

  test('not logged in -> empty profile instead of a fake sample user', () async {
    final ds = dataSource(MockClient((_) async => ok(serverUser)), currentUser: null);

    final profile = await ds.fetchProfile();

    expect(profile.displayName, isEmpty);
    expect(profile.username, isEmpty);
  });

  test('offline: cached profile of another account is not shown', () async {
    // Lưu hồ sơ của user 42 (alice) vào bộ nhớ cục bộ
    await dataSource(MockClient((_) async => ok(serverUser))).fetchProfile();

    // Người khác (id 7) đăng nhập khi backend lỗi
    final other = dataSource(MockClient((_) async => http.Response('', 503)), currentUser: const {'id': 7});
    final profile = await other.fetchProfile();

    expect(profile.displayName, isEmpty);
  });
}
