import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/notifications/data/models/notification_models.dart';
import 'package:frontend/features/notifications/data/services/notification_hub.dart';
import 'package:frontend/features/notifications/data/services/notification_service.dart';
import 'package:frontend/features/notifications/presentation/screens/notifications_screen.dart';

AppNotification _notification(
  int id,
  NotificationType type, {
  String actor = 'Hana',
  String detail = '',
  bool isRead = false,
  bool videoAvailable = true,
}) => AppNotification(
  id: id,
  type: type,
  category:
      type == NotificationType.videoApproved ||
          type == NotificationType.videoRejected
      ? NotificationCategory.system
      : NotificationCategory.interaction,
  actorId: type == NotificationType.videoApproved ? null : 2,
  actorName: actor,
  videoId: 7,
  videoTitle: 'Chào hỏi',
  videoAvailable: videoAvailable,
  detail: detail,
  isRead: isRead,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

class _FakeService extends NotificationService {
  _FakeService({
    this.interaction = const [],
    this.system = const [],
    this.pages = const {},
  });

  List<AppNotification> interaction;
  List<AppNotification> system;

  /// Trang tiếp theo của nhóm tương tác theo số trang (nếu có).
  final Map<int, NotificationPage> pages;
  final List<int> requestedPages = [];
  bool failLoad = false;

  @override
  Future<NotificationPage> fetchPage(
    NotificationCategory category, {
    int page = 0,
    int size = 20,
  }) async {
    if (failLoad) throw ApiException(statusCode: 500, message: 'lỗi máy chủ');
    if (category == NotificationCategory.interaction) {
      requestedPages.add(page);
      final extra = pages[page];
      if (extra != null) return extra;
    }
    final items = category == NotificationCategory.interaction
        ? interaction
        : system;
    return NotificationPage(items: items, isLast: true);
  }

  @override
  Future<void> markRead(int id) async {}

  @override
  Future<void> markAllRead() async {}
}

void main() {
  Future<NotificationHub> pump(
    WidgetTester tester,
    _FakeService service,
  ) async {
    final hub = NotificationHub.withService(service);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(service: service, hub: hub),
      ),
    );
    await tester.pumpAndSettle();
    return hub;
  }

  testWidgets('hiện tiêu đề, hai tab và các thông báo tương tác', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeService(
        interaction: [
          _notification(1, NotificationType.videoLiked),
          _notification(
            2,
            NotificationType.videoCommented,
            actor: 'Kenji',
            detail: 'hay quá',
          ),
        ],
      ),
    );

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tương tác'), findsOneWidget);
    expect(find.text('Hệ thống'), findsOneWidget);
    expect(find.textContaining('đã thích video của bạn'), findsOneWidget);
    expect(find.textContaining('đã bình luận về video của bạn'), findsOneWidget);
    expect(find.text('hay quá'), findsOneWidget);
    expect(find.text('5 phút trước'), findsNWidgets(2));
  });

  testWidgets('thông báo chưa đọc có chấm, đã đọc thì không', (tester) async {
    await pump(
      tester,
      _FakeService(
        interaction: [
          _notification(1, NotificationType.videoLiked),
          _notification(2, NotificationType.videoLiked, isRead: true),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
  });

  testWidgets('tab Hệ thống hiện kết quả duyệt, kèm lý do từ chối', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeService(
        system: [
          _notification(3, NotificationType.videoApproved, actor: ''),
          _notification(
            4,
            NotificationType.videoRejected,
            actor: '',
            detail: 'Nội dung vi phạm',
          ),
        ],
      ),
    );

    await tester.tap(find.text('Hệ thống'));
    await tester.pumpAndSettle();

    expect(
      find.text('Video “Chào hỏi” đã được duyệt và đăng công khai'),
      findsOneWidget,
    );
    expect(find.text('Video “Chào hỏi” đã bị từ chối'), findsOneWidget);
    expect(find.text('Lý do: Nội dung vi phạm'), findsOneWidget);
  });

  testWidgets('danh sách trống hiện lời nhắn theo từng tab', (tester) async {
    await pump(tester, _FakeService());

    expect(find.textContaining('Chưa có tương tác nào'), findsOneWidget);

    await tester.tap(find.text('Hệ thống'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có thông báo hệ thống'), findsOneWidget);
  });

  testWidgets('lỗi tải hiện thông báo lỗi và nút Thử lại', (tester) async {
    final service = _FakeService()..failLoad = true;
    await pump(tester, service);

    expect(find.text('lỗi máy chủ'), findsOneWidget);

    service
      ..failLoad = false
      ..interaction = [_notification(1, NotificationType.videoLiked)];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.textContaining('đã thích video của bạn'), findsOneWidget);
  });

  testWidgets('thông báo realtime hiện lên đầu đúng tab', (tester) async {
    final hub = await pump(
      tester,
      _FakeService(interaction: [_notification(1, NotificationType.videoLiked)]),
    );

    hub.handleIncoming(
      _notification(
        9,
        NotificationType.videoShared,
        actor: 'Mika',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mika'), findsOneWidget);
    expect(hub.unreadCount.value, 1);
  });

  testWidgets('bấm vào thông báo chưa đọc đánh dấu đã đọc', (tester) async {
    final hub = await pump(
      tester,
      _FakeService(
        interaction: [
          _notification(1, NotificationType.videoLiked, videoAvailable: false),
        ],
      ),
    );
    hub.unreadCount.value = 1;

    await tester.tap(find.textContaining('đã thích video của bạn'));
    await tester.pumpAndSettle();

    expect(hub.unreadCount.value, 0);
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
  });

  testWidgets('nút đọc tất cả chỉ bật khi còn thông báo chưa đọc', (
    tester,
  ) async {
    final hub = await pump(
      tester,
      _FakeService(interaction: [_notification(1, NotificationType.videoLiked)]),
    );

    IconButton button() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.done_all_rounded),
    );
    expect(button().onPressed, isNull);

    hub.unreadCount.value = 2;
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();

    expect(hub.unreadCount.value, 0);
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
  });

  testWidgets('danh sách ngắn còn trang sau thì tự tải tiếp', (tester) async {
    final service = _FakeService(
      pages: {
        0: NotificationPage(
          items: [_notification(1, NotificationType.videoLiked)],
          isLast: false,
        ),
        1: NotificationPage(
          items: [
            _notification(2, NotificationType.videoLiked, actor: 'Kenji'),
          ],
          isLast: true,
        ),
      },
    );
    await pump(tester, service);

    expect(service.requestedPages, [0, 1]);
    expect(find.textContaining('Kenji'), findsOneWidget);
  });
}
