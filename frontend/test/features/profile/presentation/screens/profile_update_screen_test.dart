import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_update_screen.dart';
import 'package:frontend/features/profile/presentation/widgets/interest_tags_selector.dart';
import 'package:frontend/features/profile/presentation/widgets/jlpt_level_selector.dart';

class _FakeProfileRepository implements ProfileRepository {
  UserProfileModel profile = const UserProfileModel(
    id: 1,
    username: 'test_user',
    displayName: 'Kenji Yamada',
    avatarUrl: 'https://example.com/avatar.png',
    currentLevel: 'N3',
    bio: 'Test bio description',
    interests: ['Anime & Manga', 'Giao tiếp hằng ngày'],
    topics: [
      TopicModel(id: 1, name: 'Anime & Manga'),
      TopicModel(id: 2, name: 'Giao tiếp hằng ngày'),
    ],
  );

  final List<TopicModel> topics = const [
    TopicModel(id: 1, name: 'Anime & Manga'),
    TopicModel(id: 2, name: 'Giao tiếp hằng ngày'),
    TopicModel(id: 3, name: 'Luyện thi JLPT'),
    TopicModel(id: 4, name: 'Văn hóa & Du lịch'),
  ];

  bool updateProfileCalled = false;

  @override
  Future<UserProfileModel> getProfile({int? userId}) async {
    return profile;
  }

  @override
  Future<List<TopicModel>> getTopics() async {
    return topics;
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel updated, {int? userId}) async {
    updateProfileCalled = true;
    profile = updated;
    return profile;
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse implements HttpClientResponse {
  static final List<int> _kTransparentImage = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x52, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05,
    0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
    0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  testWidgets('ProfileUpdateScreen loads and renders profile data correctly',
      (WidgetTester tester) async {
    final fakeRepo = _FakeProfileRepository();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileUpdateScreen(repository: fakeRepo),
      ),
    );

    // Initial render & wait for async getProfile/getTopics
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify title and display name loaded
    expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
    expect(find.text('Kenji Yamada'), findsOneWidget);

    // Verify JlptLevelSelector and InterestTagsSelector exist
    expect(find.byType(JlptLevelSelector), findsOneWidget);
    expect(find.byType(InterestTagsSelector), findsOneWidget);

    // Verify all 5 JLPT levels rendered
    expect(find.text('N5'), findsOneWidget);
    expect(find.text('N4'), findsOneWidget);
    expect(find.text('N3'), findsOneWidget);
    expect(find.text('N2'), findsOneWidget);
    expect(find.text('N1'), findsOneWidget);

    // Select N1
    await tester.tap(find.text('N1'));
    await tester.pump();

    // Select topic 'Luyện thi JLPT'
    await tester.tap(find.text('Luyện thi JLPT'));
    await tester.pump();

    // Tap Save Changes
    final saveButton = find.widgetWithText(ElevatedButton, 'Lưu thay đổi');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify repository updateProfile was called
    expect(fakeRepo.updateProfileCalled, isTrue);
    expect(fakeRepo.profile.currentLevel, equals('N1'));
    expect(fakeRepo.profile.interests.contains('Luyện thi JLPT'), isTrue);
  });
}
