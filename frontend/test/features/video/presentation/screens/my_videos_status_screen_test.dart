import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/video/domain/models/user_video_model.dart';
import 'package:frontend/features/video/presentation/screens/my_videos_status_screen.dart';

class _FakeRepository implements ProfileRepository {
  _FakeRepository(this.videos);

  final List<UserVideoModel> videos;

  @override
  Future<List<UserVideoModel>> getMyVideosStatus() async => videos;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserVideoModel _video(int id, String title, String modStatus, {String? createdAt, String? reason}) =>
    UserVideoModel(
      id: id,
      title: title,
      videoUrl: 'https://example.com/$id.mp4',
      modStatus: modStatus,
      createdAt: createdAt,
      rejectionReason: reason,
    );

Future<void> _pump(WidgetTester tester, List<UserVideoModel> videos) async {
  await tester.pumpWidget(MaterialApp(
    home: MyVideosStatusScreen(repository: _FakeRepository(videos)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('formatVideoDate', () {
    final now = DateTime(2026, 10, 27, 22, 0);

    test('cùng ngày thì "Hôm nay, giờ:phút"', () {
      expect(formatVideoDate(DateTime(2026, 10, 27, 21, 40).toIso8601String(), now), 'Hôm nay, 21:40');
    });

    test('ngày khác trong năm thì "dd/MM"', () {
      expect(formatVideoDate(DateTime(2026, 10, 25, 9, 0).toIso8601String(), now), '25/10');
    });

    test('khác năm thì thêm năm', () {
      expect(formatVideoDate(DateTime(2025, 12, 3, 9, 0).toIso8601String(), now), '03/12/2025');
    });

    test('thiếu hoặc sai định dạng thì rỗng', () {
      expect(formatVideoDate(null, now), '');
      expect(formatVideoDate('không phải ngày', now), '');
    });
  });

  testWidgets('chưa có video nào thì hiện "Chưa có video nào" và các tab đều bằng 0', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Chờ duyệt'), findsOneWidget); // chỉ có tiêu đề: nhãn tab nằm trong Text.rich
    expect(find.byKey(const ValueKey('empty-videos')), findsOneWidget);
    expect(find.text('Chưa có video nào'), findsOneWidget);
    expect(find.textContaining('Tất cả  0', findRichText: true), findsOneWidget);
    expect(find.textContaining('Từ chối  0', findRichText: true), findsOneWidget);
  });

  testWidgets('hiện số lượng từng tab, trạng thái và lý do từ chối màu đỏ', (tester) async {
    await _pump(tester, [
      _video(1, 'Umayuru: Thám tử lừng danh', 'PENDING'),
      _video(2, 'Hội thoại đặt phòng khách sạn', 'APPROVED'),
      _video(3, 'Chào hỏi cơ bản mỗi ngày', 'REJECTED', reason: 'Video có nhạc nền vi phạm bản quyền.'),
      _video(4, 'Hỏi đường ở ga tàu', 'APPROVED'),
    ]);

    expect(find.textContaining('Tất cả  4', findRichText: true), findsOneWidget);
    expect(find.textContaining('Chờ duyệt  1', findRichText: true), findsOneWidget);
    expect(find.textContaining('Đã duyệt  2', findRichText: true), findsOneWidget);
    expect(find.textContaining('Từ chối  1', findRichText: true), findsOneWidget);

    expect(find.text('Umayuru: Thám tử lừng danh'), findsOneWidget);
    expect(find.text('Video có nhạc nền vi phạm bản quyền.'), findsOneWidget);
    // Lý do chỉ hiện cho video bị từ chối.
    expect(find.byKey(const ValueKey('rejection-reason')), findsOneWidget);
  });

  testWidgets('chọn tab lọc danh sách theo trạng thái', (tester) async {
    await _pump(tester, [
      _video(1, 'Video chờ', 'PENDING'),
      _video(2, 'Video đã duyệt', 'APPROVED'),
    ]);

    await tester.tap(find.byKey(const ValueKey('status-tab-APPROVED')));
    await tester.pump();

    expect(find.text('Video đã duyệt'), findsOneWidget);
    expect(find.text('Video chờ'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('status-tab-REJECTED')));
    await tester.pump();

    expect(find.text('Chưa có video nào'), findsOneWidget);
  });
}
