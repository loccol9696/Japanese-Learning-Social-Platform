import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/auth_session.dart';
import '../models/chat_models.dart';
import 'chat_service.dart';
import 'chat_socket_service.dart';

/// Điểm trung tâm của chat ở mức app:
/// - bật/tắt socket theo trạng thái đăng nhập;
/// - giữ số tin chưa đọc cho badge ở icon Inbox;
/// - gửi tin văn bản (ưu tiên socket, dự phòng bằng REST).
class ChatHub {
  ChatHub._();

  static final ChatHub instance = ChatHub._();

  final ChatService _service = ChatService();
  final ChatSocketService _socket = ChatSocketService.instance;

  /// Tổng số tin chưa đọc của mọi hội thoại.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Hội thoại đang mở trên màn hình: tin mới của hội thoại này không tính chưa đọc.
  int? activeConversationId;

  bool _initialized = false;
  bool _wasAuthenticated = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Gọi một lần khi khởi động app.
  void init() {
    if (_initialized) return;
    _initialized = true;
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

  void _onAuthChanged() {
    final authenticated = AuthSession.instance.isAuthenticated;
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;
    if (authenticated) {
      _socket.connect();
      unawaited(refreshUnread());
    } else {
      _socket.disconnect();
      activeConversationId = null;
      unreadCount.value = 0;
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

  /// Gửi tin văn bản: socket trước, lỗi mạng thì chuyển sang REST.
  /// Lỗi nghiệp vụ của server (vd. 403 chưa follow lẫn nhau) được ném lại nguyên vẹn.
  Future<ChatMessage> sendText({
    required int conversationId,
    required String content,
    required String clientMsgId,
  }) async {
    try {
      return await _socket.sendText(
        conversationId: conversationId,
        content: content,
        clientMsgId: clientMsgId,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 503) rethrow;
      return _service.sendText(conversationId, content, clientMsgId);
    }
  }

  /// Đánh dấu đã đọc: socket trước, dự phòng REST.
  Future<void> markRead(int conversationId, int lastMessageId) async {
    try {
      await _socket.markRead(conversationId, lastMessageId);
    } on ApiException catch (error) {
      if (error.statusCode != 503) return;
      try {
        await _service.markRead(conversationId, lastMessageId);
      } on ApiException catch (_) {
        // Sẽ được đánh dấu lại lần mở hội thoại sau.
      }
    }
    unawaited(refreshUnread());
  }
}
