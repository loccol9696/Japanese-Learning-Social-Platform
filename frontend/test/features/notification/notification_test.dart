import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/notification/notification_hub.dart';
import 'package:frontend/features/notification/notification_model.dart';
import 'package:frontend/features/notification/notification_screen.dart';
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

  group('NotificationScreen', () {
    List<AppNotification> sample() => [
          AppNotification.fromJson(_raw(
            id: 1, type: 'LIKE', actorId: 2, actor: 'Sakura', videoId: 9, videoTitle: 'Bài 1')),
          AppNotification.fromJson(_raw(
            id: 2, type: 'VIDEO_REJECTED', isRead: true, message: 'Vi phạm bản quyền')),
        ];

    testWidgets('hiện danh sách, thông báo chưa đọc có chấm', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NotificationScreen(service: _FakeService(sample())),
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
      await tester.pumpWidget(MaterialApp(home: NotificationScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();

      expect(service.markAllCalls, 1);
      expect(NotificationHub.instance.unreadCount.value, 0);
    });

    testWidgets('trạng thái trống', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NotificationScreen(service: _FakeService(const [])),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa có thông báo nào.'), findsOneWidget);
    });
  });
}
