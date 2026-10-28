import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/notification/notification_hub.dart';
import 'package:frontend/features/notification/notification_model.dart';
import 'package:frontend/features/notification/notification_sheet.dart';
import 'package:frontend/features/notification/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _raw({
  required int id,
  required String type,
  bool isRead = false,
  int? actorId,
  String actor = '',
  int? videoId,
  String videoTitle = '',
  String message = '',
}) =>
    {
      'id': id,
      'type': type,
      'isRead': isRead,
      'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      'actorId': actorId,
      'actorUsername': actor,
      'actorDisplayName': actor,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'message': message,
    };

/// Service giả: không đụng mạng, ghi lại lời gọi.
class _FakeService implements NotificationService {
  _FakeService(this.items);

  final List<AppNotification> items;
  int markAllCalls = 0;
  final List<int> markedRead = [];

  @override
  Future<NotificationPage> fetch({int page = 0, int size = 20}) async =>
      NotificationPage(items: items, isLast: true);

  @override
  Future<int> fetchUnreadCount() async => items.where((e) => !e.isRead).length;

  @override
  Future<void> markAllRead() async => markAllCalls++;

  @override
  Future<void> markRead(int id) async => markedRead.add(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    NotificationHub.instance.setUnread(0);
  });

  group('AppNotification', () {
    test('dựng câu mô tả theo loại', () {
      final like = AppNotification.fromJson(_raw(
        id: 1, type: 'LIKE', actorId: 2, actor: 'Sakura', videoId: 9, videoTitle: 'Bài 1'));
      expect(like.title, 'Sakura đã thích video "Bài 1" của bạn');

      final follow = AppNotification.fromJson(_raw(id: 2, type: 'FOLLOW', actorId: 3, actor: 'Tanaka'));
      expect(follow.title, 'Tanaka đã bắt đầu theo dõi bạn');

      final approved = AppNotification.fromJson(_raw(id: 3, type: 'VIDEO_APPROVED', videoTitle: 'Bài 2'));
      expect(approved.title, 'Video "Bài 2" của bạn đã được duyệt');
      expect(approved.actorName, 'Ai đó');
    });

    test('loại lạ không làm hỏng việc parse', () {
      final n = AppNotification.fromJson(_raw(id: 4, type: 'SOMETHING_NEW'));
      expect(n.type, NotificationType.unknown);
      expect(n.title, 'Bạn có thông báo mới');
    });
  });

  group('NotificationService', () {
    late List<http.Request> requests;

    void useServer(http.Response Function(http.Request) handler) {
      requests = [];
      ApiClient.overrideForTesting(MockClient((request) async {
        requests.add(request);
        return handler(request);
      }));
    }

    test('fetch đọc content và cờ last', () async {
      useServer((_) => _json({
            'data': {
              'content': [_raw(id: 1, type: 'FOLLOW', actorId: 2, actor: 'A')],
              'last': false,
            }
          }));

      final page = await NotificationService().fetch(page: 1, size: 5);

      expect(page.items.single.type, NotificationType.follow);
      expect(page.isLast, isFalse);
      expect(requests.single.url.toString(),
          '${ApiConstants.notificationsUrl}?page=1&size=5');
    });

    test('đọc số chưa đọc và gọi đúng endpoint đánh dấu đã đọc', () async {
      useServer((_) => _json({'data': {'count': 4}}));
      final service = NotificationService();

      expect(await service.fetchUnreadCount(), 4);
      await service.markRead(12);
      await service.markAllRead();

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/v1/notifications/unread-count',
        'POST /api/v1/notifications/12/read',
        'POST /api/v1/notifications/read-all',
      ]);
    });
  });

  group('NotificationSheet', () {
    List<AppNotification> sample() => [
          AppNotification.fromJson(_raw(
            id: 1, type: 'LIKE', actorId: 2, actor: 'Sakura', videoId: 9, videoTitle: 'Bài 1')),
          AppNotification.fromJson(_raw(
            id: 2, type: 'VIDEO_REJECTED', isRead: true, message: 'Vi phạm bản quyền')),
        ];

    testWidgets('hiện danh sách, thông báo chưa đọc có chấm', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NotificationSheet(service: _FakeService(sample()))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sakura đã thích video "Bài 1" của bạn'), findsOneWidget);
      expect(find.text('Vi phạm bản quyền'), findsOneWidget);
      // Chấm chưa đọc chỉ có ở thông báo đầu.
      expect(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 9),
        findsOneWidget,
      );
    });

    testWidgets('"Đọc tất cả" gọi server và xoá badge', (tester) async {
      final service = _FakeService(sample());
      NotificationHub.instance.setUnread(1);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationSheet(service: service))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();

      expect(service.markAllCalls, 1);
      expect(NotificationHub.instance.unreadCount.value, 0);
    });

    /// Mở bảng thông báo bằng nút bấm, kèm vài route giả để kiểm tra việc chuyển trang.
    Future<void> openSheet(WidgetTester tester, _FakeService service) async {
      await tester.pumpWidget(MaterialApp(
        routes: {'/my-videos-status': (_) => const Scaffold(body: Text('MÀN QUẢN LÝ ĐĂNG TẢI'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNotificationsSheet(context, service: service),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
    }

    testWidgets('hiện dưới dạng bảng từ dưới lên có tiêu đề và nút đóng', (tester) async {
      await openSheet(tester, _FakeService(sample()));

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Đọc tất cả'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsNothing);
    });

    testWidgets('ẩn "Đọc tất cả" khi mọi thông báo đã đọc', (tester) async {
      await openSheet(tester, _FakeService([
        AppNotification.fromJson(_raw(id: 2, type: 'VIDEO_REJECTED', isRead: true)),
      ]));

      expect(find.text('Đọc tất cả'), findsNothing);
    });

    testWidgets('mở thông báo có đích đến thì đóng bảng rồi chuyển trang', (tester) async {
      await openSheet(tester, _FakeService([
        AppNotification.fromJson(_raw(id: 2, type: 'VIDEO_REJECTED', isRead: true, message: 'Vi phạm bản quyền')),
      ]));

      await tester.tap(find.text('Vi phạm bản quyền'));
      await tester.pumpAndSettle();

      expect(find.text('MÀN QUẢN LÝ ĐĂNG TẢI'), findsOneWidget);
      expect(find.text('Thông báo'), findsNothing);
    });

    testWidgets('thông báo không có đích đến thì giữ nguyên bảng', (tester) async {
      await openSheet(tester, _FakeService([
        AppNotification.fromJson(_raw(id: 3, type: 'CONTENT_REMOVED', isRead: true, message: 'Nội dung đã bị gỡ')),
      ]));

      await tester.tap(find.text('Nội dung đã bị gỡ'));
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsOneWidget);
    });

    testWidgets('trạng thái trống', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NotificationSheet(service: _FakeService(const []))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa có thông báo nào.'), findsOneWidget);
    });
  });
}
