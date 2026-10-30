import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/notifications/data/models/notification_models.dart';
import 'package:frontend/features/notifications/data/services/notification_hub.dart';
import 'package:frontend/features/notifications/data/services/notification_service.dart';

class _FakeService extends NotificationService {
  final List<int> read = [];
  int readAllCalls = 0;
  bool failMarkRead = false;

  @override
  Future<void> markRead(int id) async {
    if (failMarkRead) {
      throw ApiException(statusCode: 503, message: 'mất mạng');
    }
    read.add(id);
  }

  @override
  Future<void> markAllRead() async => readAllCalls++;
}

AppNotification _notification(int id, {bool isRead = false}) => AppNotification(
  id: id,
  type: NotificationType.videoLiked,
  category: NotificationCategory.interaction,
  isRead: isRead,
  createdAt: DateTime(2026, 10, 31),
);

void main() {
  late _FakeService service;
  late NotificationHub hub;

  setUp(() {
    service = _FakeService();
    hub = NotificationHub.withService(service);
  });

  test('thông báo mới tăng số chưa đọc và được phát cho màn danh sách', () async {
    final received = <int>[];
    hub.onNew.listen((n) => received.add(n.id));

    hub.handleIncoming(_notification(1));
    hub.handleIncoming(_notification(2));
    await Future<void>.delayed(Duration.zero);

    expect(hub.unreadCount.value, 2);
    expect(received, [1, 2]);
  });

  test('thông báo đã đọc sẵn không tăng số chưa đọc', () {
    hub.handleIncoming(_notification(1, isRead: true));

    expect(hub.unreadCount.value, 0);
  });

  test('markRead giảm số chưa đọc ngay, phát id và gọi server', () async {
    final readIds = <int>[];
    hub.onRead.listen(readIds.add);
    hub.unreadCount.value = 3;

    await hub.markRead(5);
    await Future<void>.delayed(Duration.zero);

    expect(hub.unreadCount.value, 2);
    expect(readIds, [5]);
    expect(service.read, [5]);
  });

  test('markRead không để số chưa đọc âm', () async {
    await hub.markRead(5);

    expect(hub.unreadCount.value, 0);
  });

  test('markRead lỗi mạng không ném lỗi ra ngoài', () async {
    service.failMarkRead = true;
    hub.unreadCount.value = 1;

    await expectLater(hub.markRead(5), completes);
  });

  test('markAllRead về 0, phát sự kiện và gọi server', () async {
    var allRead = 0;
    hub.onReadAll.listen((_) => allRead++);
    hub.unreadCount.value = 4;

    await hub.markAllRead();
    await Future<void>.delayed(Duration.zero);

    expect(hub.unreadCount.value, 0);
    expect(allRead, 1);
    expect(service.readAllCalls, 1);
  });

  test('takePendingTarget chỉ trả đích đang chờ một lần', () {
    const target = NotificationTarget(
      notificationId: 1,
      type: NotificationType.videoApproved,
      videoId: 7,
    );
    hub.pendingTarget.value = target;

    expect(hub.takePendingTarget(), same(target));
    expect(hub.takePendingTarget(), isNull);
    expect(hub.pendingTarget.value, isNull);
  });

  test('chưa đăng nhập thì bỏ qua đích từ thông báo đẩy', () {
    hub.openFromPush(
      const NotificationTarget(
        notificationId: 1,
        type: NotificationType.videoLiked,
        videoId: 7,
      ),
    );

    expect(hub.pendingTarget.value, isNull);
  });
}
