import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../notifications/data/models/notification_models.dart';
import 'chat_service.dart';

/// Thông báo đẩy (tin nhắn chat và thông báo tương tác / hệ thống) qua Firebase Cloud Messaging.
///
/// Cấu hình Firebase truyền lúc build bằng `--dart-define` (xem [_options]), không dùng
/// google-services.json. Thiếu cấu hình, hoặc chạy trên web/desktop, thì mọi hàm ở đây
/// không làm gì và chat vẫn hoạt động bình thường qua socket.
class ChatPushService {
  ChatPushService._();

  static final ChatPushService instance = ChatPushService._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  final ChatService _service = ChatService();
  final _openConversationController = StreamController<int>.broadcast();
  final _openNotificationController =
      StreamController<NotificationTarget>.broadcast();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefresh;

  /// Người dùng bấm vào thông báo: id hội thoại cần mở.
  Stream<int> get onOpenConversation => _openConversationController.stream;

  /// Người dùng bấm vào thông báo tương tác / hệ thống: đích cần mở.
  Stream<NotificationTarget> get onOpenNotification =>
      _openNotificationController.stream;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static FirebaseOptions get _options => const FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
  );

  /// Gọi sau khi đăng nhập: xin quyền và đăng ký thiết bị với backend.
  Future<void> enable() async {
    if (!_supported) return;
    try {
      await _ensureInitialized();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      await _tokenRefresh?.cancel();
      _tokenRefresh = messaging.onTokenRefresh.listen(
        (token) => unawaited(_register(token)),
      );
    } catch (error) {
      debugPrint('Không bật được thông báo đẩy: $error');
    }
  }

  /// Gọi khi đăng xuất. Lúc này đã mất access token nên không gọi backend được: huỷ
  /// token trên Firebase, lần gửi kế tiếp backend nhận 404 và tự xoá.
  Future<void> disable() async {
    if (!_supported || !_initialized) return;
    try {
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Không tắt được thông báo đẩy: $error');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Firebase.initializeApp(options: _options);
    _initialized = true;

    FirebaseMessaging.onMessageOpenedApp.listen(_openFrom);
    // App đang tắt hẳn và được mở từ thông báo.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openFrom(initial);
  }

  Future<void> _register(String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await _service.registerDevice(token, platform);
  }

  void _openFrom(RemoteMessage message) {
    final notification = NotificationTarget.fromPushData(message.data);
    if (notification != null) {
      _openNotificationController.add(notification);
      return;
    }
    final id = int.tryParse('${message.data['conversationId']}');
    if (id != null) _openConversationController.add(id);
  }
}
