import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/video_actions_sheet.dart';
import 'package:frontend/features/home/presentation/widgets/video_player_item.dart';
import 'package:frontend/features/video/data/services/video_trash_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Nền tảng phát video giả: khởi tạo xong ngay và ghi lại các tốc độ được đặt.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final List<double> speeds = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(720, 1280),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setWebOptions(int playerId, VideoPlayerWebOptions options) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();
}

const _me = 7;

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

http.Response _ok(Object? body) => http.Response(
  jsonEncode({'status': 200, 'data': body}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

VideoPost _post({String id = '12', int? creatorId = 7, String videoUrl = ''}) {
  return VideoPost(
    id: id,
    backgroundImageUrl: '',
    videoUrl: videoUrl,
    creatorName: 'Hana',
    creatorId: creatorId,
    creatorTag: '@hana',
    creatorAvatarUrl: '',
    accentInfo: '',
    jlptLevel: 'N3',
    topicTag: '',
    audioTitle: '',
    audioDiscImageUrl: '',
    rubySegments: const [],
    translation: '',
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
  );
}

void main() {
  Future<void> pumpPlayer(
    WidgetTester tester,
    VideoPost post, {
    VoidCallback? onDeleted,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoPlayerItem(post: post, onDeleted: onDeleted)),
      ),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.longPress(find.byType(VideoPlayerItem));
    await tester.pumpAndSettle();
  }

  group('VideoActionsSheet', () {
    Future<VideoAction?> chooseAction(
      WidgetTester tester, {
      required String label,
      bool canChangeSpeed = true,
      bool canDelete = false,
    }) async {
      VideoAction? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showVideoActionsSheet(
                    context,
                    isDoubleSpeed: false,
                    canChangeSpeed: canChangeSpeed,
                    canOpenCreator: true,
                    canReport: true,
                    canDelete: canDelete,
                    creatorName: 'Hana',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('trả về đúng thao tác đã chọn', (tester) async {
      expect(
        await chooseAction(tester, label: 'Phát tốc độ x2'),
        VideoAction.toggleDoubleSpeed,
      );
      expect(
        await chooseAction(tester, label: 'Xem trang của Hana'),
        VideoAction.openCreator,
      );
      expect(
        await chooseAction(tester, label: 'Báo cáo video'),
        VideoAction.report,
      );
      expect(
        await chooseAction(tester, label: 'Xóa video', canDelete: true),
        VideoAction.delete,
      );
    });

    testWidgets('x2 bị vô hiệu khi video chưa tải xong', (tester) async {
      await chooseAction(tester, label: 'Phát tốc độ x2', canChangeSpeed: false);
      // Bấm không có tác dụng nên menu vẫn mở.
      expect(find.text('Phát tốc độ x2'), findsOneWidget);
    });
  });

  group('VideoPlayerItem nhấn giữ', () {
    testWidgets('hiện đủ thao tác với video của người khác', (tester) async {
      await pumpPlayer(tester, _post());
      await openMenu(tester);

      expect(find.text('Phát tốc độ x2'), findsOneWidget);
      expect(find.text('Xem trang của Hana'), findsOneWidget);
      expect(find.text('Báo cáo video'), findsOneWidget);
    });

    testWidgets('ẩn báo cáo và trang người đăng khi không có dữ liệu', (
      tester,
    ) async {
      await pumpPlayer(tester, _post(id: 'sample', creatorId: null));
      await openMenu(tester);

      expect(find.text('Báo cáo video'), findsNothing);
      expect(find.text('Xem trang của Hana'), findsNothing);
    });

    testWidgets('bật x2 rồi về tốc độ thường', (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = _FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);

      await pumpPlayer(tester, _post(videoUrl: 'https://example.com/v.mp4'));
      await tester.pump();

      await openMenu(tester);
      await tester.tap(find.text('Phát tốc độ x2'));
      await tester.pumpAndSettle();
      expect(platform.speeds.last, 2.0);
      expect(find.text('2x'), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.text('Về tốc độ thường'));
      await tester.pumpAndSettle();
      expect(platform.speeds.last, 1.0);
      expect(find.text('2x'), findsNothing);

      // Hủy controller để dừng timer cập nhật vị trí phát.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('VideoPlayerItem xóa video', () {
    late List<http.Request> requests;
    late FutureOr<http.Response> Function(http.Request) server;

    Iterable<http.Request> deletes() =>
        requests.where((r) => r.method == 'DELETE');

    /// Bấm Xóa video trong menu rồi trả lời hộp thoại xác nhận bằng [answer].
    Future<void> chooseDelete(WidgetTester tester, String answer) async {
      await openMenu(tester);
      await tester.tap(find.text('Xóa video'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa video?'), findsOneWidget);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
    }

    /// Chờ toast tự tắt để không còn timer treo khi test kết thúc.
    Future<void> waitForToast(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      requests = [];
      ApiClient.overrideForTesting(
        MockClient((request) async {
          requests.add(request);
          return server(request);
        }),
      );
      server = (_) => _ok({
        'tokenType': 'Bearer',
        'accessToken': _jwt(),
        'refreshToken': 'rt',
        'expiresIn': 3600,
        'user': {'id': _me, 'username': 'me', 'email': 'me@example.com'},
      });
      await AuthSession.instance.login(
        email: 'me@example.com',
        password: 'secret1',
        rememberMe: true,
      );
      requests.clear();
      server = (_) => _ok(null);
    });

    tearDown(() => AuthSession.instance.logout());

    testWidgets('chủ video thấy mục xóa thay cho báo cáo', (tester) async {
      await pumpPlayer(tester, _post(creatorId: _me), onDeleted: () {});
      await openMenu(tester);

      expect(find.text('Xóa video'), findsOneWidget);
      expect(find.text('Báo cáo video'), findsNothing);
    });

    testWidgets('video của người khác không có mục xóa', (tester) async {
      await pumpPlayer(tester, _post(creatorId: _me + 1), onDeleted: () {});
      await openMenu(tester);

      expect(find.text('Xóa video'), findsNothing);
      expect(find.text('Báo cáo video'), findsOneWidget);
    });

    testWidgets('video mẫu không có mục xóa', (tester) async {
      await pumpPlayer(
        tester,
        _post(id: 'sample', creatorId: _me),
        onDeleted: () {},
      );
      await openMenu(tester);

      expect(find.text('Xóa video'), findsNothing);
    });

    testWidgets('xác nhận thì gọi API xóa và báo màn chứa', (tester) async {
      var deleted = 0;
      final trashed = <int>[];
      final subscription = VideoTrashService.trashedVideoIds.listen(trashed.add);
      addTearDown(subscription.cancel);
      await pumpPlayer(
        tester,
        _post(creatorId: _me),
        onDeleted: () => deleted++,
      );

      await chooseDelete(tester, 'Xóa');

      expect(deletes().single.url.path, endsWith('/videos/12'));
      expect(deleted, 1);
      expect(trashed, [12]);
      expect(find.text('Đã chuyển video vào thùng rác'), findsOneWidget);
      await waitForToast(tester);
    });

    testWidgets('hủy xác nhận thì không xóa', (tester) async {
      var deleted = 0;
      await pumpPlayer(
        tester,
        _post(creatorId: _me),
        onDeleted: () => deleted++,
      );

      await chooseDelete(tester, 'Hủy');

      expect(deletes(), isEmpty);
      expect(deleted, 0);
    });

    testWidgets('API lỗi thì báo lỗi và giữ nguyên video', (tester) async {
      var deleted = 0;
      final trashed = <int>[];
      final subscription = VideoTrashService.trashedVideoIds.listen(trashed.add);
      addTearDown(subscription.cancel);
      server = (_) => http.Response(
        jsonEncode({'status': 403, 'message': 'Không có quyền'}),
        403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      await pumpPlayer(
        tester,
        _post(creatorId: _me),
        onDeleted: () => deleted++,
      );

      await chooseDelete(tester, 'Xóa');

      expect(deleted, 0);
      expect(trashed, isEmpty);
      expect(find.textContaining('Không thể xóa video'), findsOneWidget);
      await waitForToast(tester);
    });
  });
}
