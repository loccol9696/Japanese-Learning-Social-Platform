import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/video_actions_sheet.dart';
import 'package:frontend/features/home/presentation/widgets/video_player_item.dart';
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
  Future<void> pumpPlayer(WidgetTester tester, VideoPost post) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VideoPlayerItem(post: post))),
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
}
