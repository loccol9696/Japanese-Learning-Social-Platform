import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/auth_session.dart';
import '../../../chat/data/services/chat_push_service.dart';
import '../../../chat/data/services/chat_socket_service.dart';
import '../models/notification_models.dart';
import 'notification_service.dart';

/// Điểm trung tâm của thông báo ở mức app:
/// - giữ số thông báo chưa đọc cho badge ở icon chuông;
/// - nhận thông báo mới qua socket của chat và chuyển cho màn danh sách đang mở;
/// - giữ đích cần mở khi người dùng bấm vào thông báo đẩy cho tới khi Home sẵn sàng.
///
/// Socket do `ChatHub` bật/tắt theo đăng nhập; hub này chỉ lắng nghe.
class NotificationHub with WidgetsBindingObserver {
  NotificationHub._() : _service = NotificationService();

  @visibleForTesting
  NotificationHub.withService(this._service);

  static final NotificationHub instance = NotificationHub._();

  final NotificationService _service;

  /// Tổng số thông báo chưa đọc (cả hai nhóm).
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Đích cần mở sau khi bấm thông báo đẩy; Home lấy ra bằng [takePendingTarget].
  final ValueNotifier<NotificationTarget?> pendingTarget =
      ValueNotifier<NotificationTarget?>(null);

  final _newController = StreamController<AppNotification>.broadcast();
  final _readController = StreamController<int>.broadcast();
  final _readAllController = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _wasAuthenticated = false;

  /// Thông báo mới vừa đến (realtime).
  Stream<AppNotification> get onNew => _newController.stream;

  /// Id thông báo vừa được đánh dấu đã đọc từ app này.
  Stream<int> get onRead => _readController.stream;

  /// Tất cả thông báo vừa được đánh dấu đã đọc.
  Stream<void> get onReadAll => _readAllController.stream;

  /// Gọi một lần khi khởi động app.
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_onAuthChanged);
    final socket = ChatSocketService.instance;
    _subscriptions
      ..add(socket.onNotification.listen(handleIncoming))
      ..add(
        socket.onConnectionChanged.listen((connected) {
          // Có thể đã lỡ thông báo trong lúc mất kết nối → đếm lại từ server.
          if (connected) unawaited(refreshUnread());
        }),
      )
      ..add(ChatPushService.instance.onOpenNotification.listen(openFromPush));
    _onAuthChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        AuthSession.instance.isAuthenticated) {
      unawaited(refreshUnread());
    }
  }

  void _onAuthChanged() {
    final authenticated = AuthSession.instance.isAuthenticated;
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;
    if (authenticated) {
      unawaited(refreshUnread());
    } else {
      unreadCount.value = 0;
      pendingTarget.value = null;
    }
  }

  Future<void> refreshUnread() async {
    if (!AuthSession.instance.isAuthenticated) return;
    try {
      unreadCount.value = await _service.fetchUnreadCount();
    } on ApiException catch (error) {
      debugPrint('Không tải được số thông báo chưa đọc: ${error.message}');
    }
  }

  @visibleForTesting
  void handleIncoming(AppNotification notification) {
    if (!notification.isRead) unreadCount.value = unreadCount.value + 1;
    _newController.add(notification);
  }

  /// Đánh dấu một thông báo chưa đọc là đã đọc. Cập nhật ngay trên giao diện,
  /// lỗi mạng thì đếm lại từ server.
  Future<void> markRead(int id) async {
    if (unreadCount.value > 0) unreadCount.value = unreadCount.value - 1;
    _readController.add(id);
    try {
      await _service.markRead(id);
    } on ApiException catch (error) {
      debugPrint('Không đánh dấu được đã đọc: ${error.message}');
      unawaited(refreshUnread());
    }
  }

  /// Đánh dấu đã đọc khi mở từ thông báo đẩy. Không biết thông báo đã đọc từ trước hay chưa
  /// nên đếm lại từ server thay vì tự trừ.
  Future<void> markReadFromPush(int id) async {
    _readController.add(id);
    try {
      await _service.markRead(id);
    } on ApiException catch (error) {
      debugPrint('Không đánh dấu được đã đọc: ${error.message}');
    }
    await refreshUnread();
  }

  Future<void> markAllRead() async {
    unreadCount.value = 0;
    _readAllController.add(null);
    try {
      await _service.markAllRead();
    } on ApiException catch (error) {
      debugPrint('Không đánh dấu được tất cả đã đọc: ${error.message}');
      unawaited(refreshUnread());
    }
  }

  /// Người dùng bấm vào thông báo đẩy.
  void openFromPush(NotificationTarget target) {
    if (!AuthSession.instance.isAuthenticated) return;
    pendingTarget.value = target;
  }

  /// Lấy đích đang chờ (và xoá nó) để chỉ mở đúng một lần.
  NotificationTarget? takePendingTarget() {
    final target = pendingTarget.value;
    pendingTarget.value = null;
    return target;
  }
}
