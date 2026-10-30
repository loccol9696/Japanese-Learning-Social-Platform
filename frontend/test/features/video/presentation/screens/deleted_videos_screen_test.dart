import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/video/data/services/video_trash_service.dart';
import 'package:frontend/features/video/domain/models/user_video_model.dart';
import 'package:frontend/features/video/presentation/screens/deleted_videos_screen.dart';

class _FakeTrashService implements VideoTrashService {
  List<UserVideoModel> videos;
  bool failActions = false;
  bool failFetch = false;
  final restored = <int>[];
  final purged = <int>[];

  _FakeTrashService(this.videos);

  @override
  Future<List<UserVideoModel>> fetchTrash() async {
    if (failFetch) throw Exception('mất mạng');
    return videos;
  }

  @override
  Future<void> restore(int videoId) async {
    if (failActions) throw Exception('lỗi server');
    restored.add(videoId);
  }

  @override
  Future<void> deletePermanently(int videoId) async {
    if (failActions) throw Exception('lỗi server');
    purged.add(videoId);
  }

  @override
  Future<void> moveToTrash(int videoId) async {}
}

UserVideoModel _video(int id, {String? purgeAt}) => UserVideoModel(
  id: id,
  title: 'Bài học $id',
  videoUrl: 'https://example.com/$id.mp4',
  commentCount: 3,
  likeCount: 5,
  purgeAt: purgeAt,
);

String _inDays(int days) =>
    DateTime.now().add(Duration(days: days, minutes: -5)).toIso8601String();

Future<void> _pump(WidgetTester tester, _FakeTrashService service) async {
  await tester.pumpWidget(
    MaterialApp(home: DeletedVideosScreen(service: service)),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiện video cùng số ngày còn lại', (tester) async {
    await _pump(
      tester,
      _FakeTrashService([_video(1, purgeAt: _inDays(12))]),
    );

    expect(find.text('Bài học 1'), findsOneWidget);
    expect(find.text('3 bình luận · 5 lượt thích'), findsOneWidget);
    expect(find.text('Còn 12 ngày trước khi xóa hẳn'), findsOneWidget);
  });

  testWidgets('thùng rác trống hiện hướng dẫn', (tester) async {
    await _pump(tester, _FakeTrashService([]));

    expect(find.textContaining('Thùng rác trống'), findsOneWidget);
  });

  testWidgets('khôi phục xong video rời khỏi danh sách', (tester) async {
    final service = _FakeTrashService([_video(1), _video(2)]);
    await _pump(tester, service);

    await tester.tap(find.text('Khôi phục').first);
    await tester.pump();
    await _settleToast(tester);

    expect(service.restored, [1]);
    expect(find.text('Bài học 1'), findsNothing);
    expect(find.text('Bài học 2'), findsOneWidget);
  });

  testWidgets('xóa vĩnh viễn phải xác nhận', (tester) async {
    final service = _FakeTrashService([_video(1)]);
    await _pump(tester, service);

    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(service.purged, isEmpty);
    expect(find.text('Bài học 1'), findsOneWidget);

    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa vĩnh viễn').last);
    await tester.pump();
    await _settleToast(tester);

    expect(service.purged, [1]);
    expect(find.text('Bài học 1'), findsNothing);
  });

  testWidgets('thao tác lỗi thì video vẫn ở lại', (tester) async {
    final service = _FakeTrashService([_video(1)])..failActions = true;
    await _pump(tester, service);

    await tester.tap(find.text('Khôi phục'));
    await tester.pump();
    await _settleToast(tester);

    expect(find.text('Bài học 1'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Khôi phục'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('tải lỗi cho phép thử lại', (tester) async {
    final service = _FakeTrashService([_video(1)])..failFetch = true;
    await _pump(tester, service);
    expect(find.text('Thử lại'), findsOneWidget);

    service.failFetch = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Bài học 1'), findsOneWidget);
  });

  group('daysUntilPurge', () {
    final now = DateTime(2026, 11, 1, 12);

    int? days(DateTime purgeAt) =>
        _video(1, purgeAt: purgeAt.toIso8601String()).daysUntilPurge(now);

    test('làm tròn lên để không báo thiếu ngày', () {
      expect(days(now.add(const Duration(days: 29, hours: 1))), 30);
      expect(days(now.add(const Duration(hours: 1))), 1);
    });

    test('quá hạn trả về 0', () {
      expect(days(now.subtract(const Duration(hours: 1))), 0);
    });

    test('không ở thùng rác trả về null', () {
      expect(_video(1).daysUntilPurge(now), isNull);
    });
  });
}
