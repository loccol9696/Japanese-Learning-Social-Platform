import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../notifications/data/models/notification_models.dart';
import '../models/chat_models.dart';

/// Kết nối Socket.IO tới server chat.
///
/// - Xác thực bằng access token qua query `?token=` (server không đọc được `auth`).
/// - Access token sống ngắn nên tự dựng lại socket với token mới mỗi lần kết nối lại
///   (backoff tăng dần, tối đa [_maxBackoff]).
/// - Dữ liệu đến được phát ra qua các [Stream] broadcast để màn hình lắng nghe.
/// - Cùng kết nối này còn đưa thông báo mới của tính năng Thông báo ([onNotification]).
class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  static const Duration _ackTimeout = Duration(seconds: 8);
  static const Duration _maxBackoff = Duration(seconds: 15);

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _recalledController = StreamController<ChatMessage>.broadcast();
  final _clearedController = StreamController<int>.broadcast();
  final _readController = StreamController<ReadReceipt>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _notificationController =
      StreamController<AppNotification>.broadcast();

  io.Socket? _socket;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _wanted = false;
  bool _connecting = false;

  Stream<ChatMessage> get onMessage => _messageController.stream;
  Stream<ChatMessage> get onRecalled => _recalledController.stream;

  /// Id hội thoại vừa được xoá (kể cả xoá từ thiết bị khác của cùng tài khoản).
  Stream<int> get onCleared => _clearedController.stream;
  Stream<ReadReceipt> get onRead => _readController.stream;
  Stream<TypingEvent> get onTyping => _typingController.stream;

  /// Thông báo mới (bình luận, thích, chia sẻ, kết quả duyệt video) gửi tới người dùng.
  Stream<AppNotification> get onNotification => _notificationController.stream;

  /// true khi vừa kết nối được, false khi mất kết nối.
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Bắt đầu giữ kết nối (gọi sau khi đăng nhập). Gọi nhiều lần không sao.
  void connect() {
    _wanted = true;
    if (isConnected || _connecting) return;
    unawaited(_open());
  }

  /// Ngắt hẳn kết nối (gọi khi đăng xuất / hết phiên).
  void disconnect() {
    _wanted = false;
    _retryTimer?.cancel();
    _attempt = 0;
    _closeSocket();
  }

  Future<void> _open() async {
    if (_connecting || !_wanted) return;
    _connecting = true;
    try {
      final token = await ApiClient.instance.validAccessToken();
      if (!_wanted) return;
      if (token == null || token.isEmpty) {
        _scheduleRetry();
        return;
      }
      _closeSocket();
      final socket = io.io(
        ApiConstants.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token})
            // Mặc định thư viện dùng chung kết nối theo URL; bắt buộc tạo mới để
            // mỗi lần kết nối lại mang đúng access token vừa làm mới.
            .enableForceNew()
            .disableAutoConnect()
            .disableReconnection()
            .build(),
      );
      _socket = socket;
      _bind(socket);
      socket.connect();
    } on ApiException catch (error) {
      debugPrint('Chat socket: không lấy được token (${error.message})');
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _bind(io.Socket socket) {
    socket.onConnect((_) {
      if (_socket != socket) return;
      _attempt = 0;
      _connectionController.add(true);
    });
    socket.onDisconnect((_) {
      if (_socket != socket) return;
      _connectionController.add(false);
      _scheduleRetry();
    });
    socket.onConnectError((error) {
      if (_socket != socket) return;
      debugPrint('Chat socket connect error: $error');
      _scheduleRetry();
    });

    socket.on('message:new', (data) {
      final json = _asMap(data);
      if (json != null) _messageController.add(ChatMessage.fromJson(json));
    });
    socket.on('message:recalled', (data) {
      final json = _asMap(data);
      if (json != null) _recalledController.add(ChatMessage.fromJson(json));
    });
    socket.on('conversation:cleared', (data) {
      final id = _asMap(data)?['conversationId'];
      if (id is num) _clearedController.add(id.toInt());
    });
    socket.on('message:read', (data) {
      final json = _asMap(data);
      if (json != null) _readController.add(ReadReceipt.fromJson(json));
    });
    socket.on('typing', (data) {
      final json = _asMap(data);
      if (json != null) _typingController.add(TypingEvent.fromJson(json));
    });
    socket.on('notification:new', (data) {
      final json = _asMap(data);
      if (json == null) return;
      final notification = AppNotification.fromJson(json);
      if (notification.type != NotificationType.unknown) {
        _notificationController.add(notification);
      }
    });
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retryTimer?.cancel();
    final delay = Duration(
      milliseconds: math.min(
        _maxBackoff.inMilliseconds,
        1000 * math.pow(2, _attempt).toInt(),
      ),
    );
    _attempt = math.min(_attempt + 1, 6);
    _retryTimer = Timer(delay, () {
      if (_wanted && !isConnected) unawaited(_open());
    });
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    socket.dispose();
  }

  // ---------------------------------------------------------------------------
  // Gửi event
  // ---------------------------------------------------------------------------

  /// Gửi tin văn bản và chờ ack. Ném [ApiException] khi server từ chối
  /// (vd. 403 chưa follow lẫn nhau) hoặc khi mất kết nối / quá hạn (statusCode 503)
  /// để nơi gọi chuyển sang gửi dự phòng qua REST.
  Future<ChatMessage> sendText({
    required int conversationId,
    required String content,
    required String clientMsgId,
    int? replyToId,
  }) {
    return _send({
      'conversationId': conversationId,
      'type': 'TEXT',
      'content': content,
      'clientMsgId': clientMsgId,
      'replyToId': ?replyToId,
    });
  }

  /// Gửi tin ảnh đã tải lên; lỗi xử lý giống [sendText].
  Future<ChatMessage> sendImage({
    required int conversationId,
    required String imageUrl,
    required String clientMsgId,
    int? replyToId,
  }) {
    return _send({
      'conversationId': conversationId,
      'type': 'IMAGE',
      'imageUrl': imageUrl,
      'clientMsgId': clientMsgId,
      'replyToId': ?replyToId,
    });
  }

  Future<ChatMessage> _send(Map<String, dynamic> payload) async {
    final data = await _emitWithAck('message:send', payload);
    final json = _asMap(data);
    if (json == null) {
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi gửi tin không hợp lệ.',
      );
    }
    return ChatMessage.fromJson(json);
  }

  /// Báo đã đọc tới [lastMessageId].
  Future<void> markRead(int conversationId, int lastMessageId) async {
    await _emitWithAck('conversation:read', {
      'conversationId': conversationId,
      'lastMessageId': lastMessageId,
    });
  }

  /// Báo đang gõ / ngừng gõ (không chờ kết quả, bỏ qua nếu chưa kết nối).
  void sendTyping(int conversationId, bool isTyping) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  Future<dynamic> _emitWithAck(String event, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(
        ApiException(
          statusCode: 503,
          message: 'Chưa kết nối tới máy chủ chat.',
        ),
      );
    }
    final completer = Completer<dynamic>();
    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        if (completer.isCompleted) return;
        final body = _asMap(
          response is List && response.isNotEmpty ? response.first : response,
        );
        if (body != null && body['ok'] == true) {
          completer.complete(body['data']);
        } else {
          completer.completeError(
            ApiException(
              statusCode: (body?['status'] as num?)?.toInt() ?? 500,
              message:
                  body?['message']?.toString() ?? 'Không thể gửi tin nhắn.',
            ),
          );
        }
      },
    );
    return completer.future.timeout(
      _ackTimeout,
      onTimeout: () => throw ApiException(
        statusCode: 503,
        message: 'Máy chủ chat không phản hồi, vui lòng thử lại.',
      ),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    final value = data is List && data.isNotEmpty ? data.first : data;
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }
}
