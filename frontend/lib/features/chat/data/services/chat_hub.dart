import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/auth_session.dart';
import '../models/chat_models.dart';
import 'chat_push_service.dart';
import 'chat_service.dart';
import 'chat_socket_service.dart';

/// Điểm trung tâm của chat ở mức app:
/// - bật/tắt socket và thông báo đẩy theo trạng thái đăng nhập;
/// - giữ số tin chưa đọc cho badge ở icon Inbox;
/// - theo dõi app có đang mở và tab Tin nhắn có đang hiển thị;
/// - gửi tin (ưu tiên socket, dự phòng bằng REST).
class ChatHub with WidgetsBindingObserver {
  ChatHub._();

  static final ChatHub instance = ChatHub._();

  final ChatService _service = ChatService();
  final ChatSocketService _socket = ChatSocketService.instance;

  /// Tổng số tin chưa đọc của mọi hội thoại.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// false khi app ở nền hoặc bị che: tin đến lúc này chưa được xem.
  final ValueNotifier<bool> appInForeground = ValueNotifier<bool>(true);

  /// Tab Tin nhắn đang được chọn. Tab được giữ sống khi chuyển tab nên màn chat bên
  /// trong vẫn tồn tại dù người dùng không nhìn thấy.
  final ValueNotifier<bool> messagesTabVisible = ValueNotifier<bool>(false);

  /// Hội thoại người dùng đang thật sự nhìn thấy: tin mới của hội thoại này không
  /// tính chưa đọc. Do [ChatDetailScreen] cập nhật.
  int? activeConversationId;

  bool _initialized = false;
  bool _wasAuthenticated = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Gọi một lần khi khởi động app.
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_onAuthChanged);
    _subscriptions
      ..add(_socket.onMessage.listen(_onMessage))
      ..add(_socket.onRead.listen(_onRead))
      ..add(
        _socket.onConnectionChanged.listen((connected) {
          // Có thể đã lỡ tin trong lúc mất kết nối → đếm lại từ server.
          if (connected) unawaited(refreshUnread());
        }),
      );
    _onAuthChanged();
  }

  int? get _myId => AuthSession.instance.user?.id;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == appInForeground.value) return;
    appInForeground.value = foreground;
    if (foreground && AuthSession.instance.isAuthenticated) {
      // Hệ điều hành có thể đã ngắt socket khi app ở nền.
      _socket.connect();
      unawaited(refreshUnread());
    }
  }

  void _onAuthChanged() {
    final authenticated = AuthSession.instance.isAuthenticated;
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;
    if (authenticated) {
      _socket.connect();
      unawaited(refreshUnread());
      unawaited(ChatPushService.instance.enable());
    } else {
      _socket.disconnect();
      activeConversationId = null;
      unreadCount.value = 0;
      unawaited(ChatPushService.instance.disable());
    }
  }

  Future<void> refreshUnread() async {
    if (!AuthSession.instance.isAuthenticated) return;
    try {
      unreadCount.value = await _service.fetchUnreadCount();
    } on ApiException catch (error) {
      debugPrint('Không tải được số tin chưa đọc: ${error.message}');
    }
  }

  void _onMessage(ChatMessage message) {
    final myId = _myId;
    if (myId == null || message.senderId == myId) return;
    if (message.conversationId == activeConversationId) return;
    unreadCount.value = unreadCount.value + 1;
  }

  void _onRead(ReadReceipt receipt) {
    // Mình đọc trên thiết bị khác → số chưa đọc đổi, đếm lại cho chính xác.
    if (receipt.userId == _myId) unawaited(refreshUnread());
  }

  /// Lỗi của đường socket (mất kết nối, token socket hết hạn) thì thử lại qua REST,
  /// vì REST tự làm mới token. Lỗi nghiệp vụ của server được ném lại nguyên vẹn.
  bool _shouldFallBackToRest(ApiException error) =>
      error.statusCode == 503 || error.statusCode == 401;

  /// Gửi tin văn bản: socket trước, lỗi mạng thì chuyển sang REST.
  /// Lỗi nghiệp vụ của server (vd. 403 chưa follow lẫn nhau) được ném lại nguyên vẹn.
  Future<ChatMessage> sendText({
    required int conversationId,
    required String content,
    required String clientMsgId,
    int? replyToId,
  }) async {
    try {
      return await _socket.sendText(
        conversationId: conversationId,
        content: content,
        clientMsgId: clientMsgId,
        replyToId: replyToId,
      );
    } on ApiException catch (error) {
      if (!_shouldFallBackToRest(error)) rethrow;
      return _service.sendText(
        conversationId,
        content,
        clientMsgId,
        replyToId: replyToId,
      );
    }
  }

  /// Gửi tin ảnh đã tải lên: socket trước, lỗi mạng thì chuyển sang REST.
  Future<ChatMessage> sendImage({
    required int conversationId,
    required String imageUrl,
    required String clientMsgId,
    int? replyToId,
  }) async {
    try {
      return await _socket.sendImage(
        conversationId: conversationId,
        imageUrl: imageUrl,
        clientMsgId: clientMsgId,
        replyToId: replyToId,
      );
    } on ApiException catch (error) {
      if (!_shouldFallBackToRest(error)) rethrow;
      return _service.sendImage(
        conversationId,
        imageUrl,
        clientMsgId,
        replyToId: replyToId,
      );
    }
  }

  /// Đánh dấu đã đọc: socket trước, dự phòng REST.
  Future<void> markRead(int conversationId, int lastMessageId) async {
    try {
      await _socket.markRead(conversationId, lastMessageId);
    } on ApiException catch (error) {
      if (!_shouldFallBackToRest(error)) return;
      try {
        await _service.markRead(conversationId, lastMessageId);
      } on ApiException catch (_) {
        // Sẽ được đánh dấu lại lần mở hội thoại sau.
      }
    }
    unawaited(refreshUnread());
  }
}
