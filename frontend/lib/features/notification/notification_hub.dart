import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/data/auth_session.dart';
import '../chat/data/services/chat_socket_service.dart';
import 'notification_model.dart';
import 'notification_service.dart';

/// Điểm trung tâm thông báo ở mức app: giữ số chưa đọc cho badge và phát thông báo mới
/// nhận qua socket (kết nối socket do [ChatHub] bật/tắt theo đăng nhập).
class NotificationHub {
  NotificationHub._();

  static final NotificationHub instance = NotificationHub._();

  final NotificationService _service = NotificationService();
  final ChatSocketService _socket = ChatSocketService.instance;

  /// Số thông báo chưa đọc.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  final _incoming = StreamController<AppNotification>.broadcast();

  /// Thông báo vừa nhận realtime (để màn danh sách chèn lên đầu).
  Stream<AppNotification> get onIncoming => _incoming.stream;

  bool _initialized = false;
  bool _wasAuthenticated = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Gọi một lần khi khởi động app.
  void init() {
    if (_initialized) return;
    _initialized = true;
    AuthSession.instance.addListener(_onAuthChanged);
    _subscriptions
      ..add(_socket.onNotification.listen(_onNotification))
      ..add(
        _socket.onConnectionChanged.listen((connected) {
          // Có thể đã lỡ thông báo trong lúc mất kết nối → đếm lại từ server.
          if (connected) unawaited(refreshUnread());
        }),
      );
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final authenticated = AuthSession.instance.isAuthenticated;
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;
    if (authenticated) {
      unawaited(refreshUnread());
    } else {
      unreadCount.value = 0;
    }
  }

  Future<void> refreshUnread() async {
    if (!AuthSession.instance.isAuthenticated) return;
    try {
      unreadCount.value = await _service.fetchUnreadCount();
    } catch (error) {
      debugPrint('Không tải được số thông báo chưa đọc: $error');
    }
  }

  void _onNotification(Map<String, dynamic> payload) {
    final raw = payload['notification'];
    if (raw is Map<String, dynamic>) {
      _incoming.add(AppNotification.fromJson(raw));
    }
    final count = payload['unreadCount'];
    if (count is num) {
      unreadCount.value = count.toInt();
    } else {
      unreadCount.value = unreadCount.value + 1;
    }
  }

  /// Cập nhật badge sau khi người dùng đọc thủ công (không cần gọi lại server).
  void setUnread(int count) => unreadCount.value = count < 0 ? 0 : count;
}
