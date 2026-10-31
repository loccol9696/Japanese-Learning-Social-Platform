import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/chat_models.dart';

/// Gọi REST API của chat. Gửi/nhận realtime đi qua [ChatSocketService];
/// các hàm ở đây dùng để tải dữ liệu và làm đường gửi dự phòng.
class ChatService {
  ChatService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// Những người follow lẫn nhau (được phép nhắn tin).
  Future<List<ChatUser>> fetchContacts() async {
    final data = await _api.get(ApiConstants.chatContactsUrl);
    return _list(data).map(ChatUser.fromJson).toList();
  }

  Future<List<Conversation>> fetchConversations() async {
    final data = await _api.get('${ApiConstants.chatConversationsUrl}?size=50');
    final content = data is Map<String, dynamic> ? data['content'] : null;
    return _list(content).map(Conversation.fromJson).toList();
  }

  /// Mở (hoặc tạo) hội thoại với một người. Server trả 403 nếu chưa follow lẫn nhau.
  Future<Conversation> openConversation(int recipientId) async {
    final data = await _api.post(
      ApiConstants.chatConversationsUrl,
      body: {'recipientId': recipientId},
    );
    return Conversation.fromJson(_map(data));
  }

  Future<Conversation> fetchConversation(int id) async {
    final data = await _api.get(ApiConstants.chatConversationUrl(id));
    return Conversation.fromJson(_map(data));
  }

  /// [before] lấy tin cũ hơn (mới nhất trước); [after] lấy tin mới hơn mốc đó
  /// (cũ nhất trước) để đồng bộ phần đã lỡ. Không dùng cả hai cùng lúc.
  Future<MessagePage> fetchMessages(
    int conversationId, {
    int? before,
    int? after,
    int size = 30,
  }) async {
    assert(before == null || after == null, 'Chỉ dùng before hoặc after');
    final query =
        'size=$size${before != null ? '&before=$before' : ''}'
        '${after != null ? '&after=$after' : ''}';
    final data = await _api.get(
      '${ApiConstants.chatMessagesUrl(conversationId)}?$query',
    );
    return MessagePage.fromJson(_map(data));
  }

  /// Đường gửi dự phòng khi socket mất kết nối.
  Future<ChatMessage> sendText(
    int conversationId,
    String content,
    String clientMsgId, {
    int? replyToId,
  }) async {
    final data = await _api.post(
      ApiConstants.chatMessagesUrl(conversationId),
      body: {
        'type': 'TEXT',
        'content': content,
        'clientMsgId': clientMsgId,
        'replyToId': ?replyToId,
      },
    );
    return ChatMessage.fromJson(_map(data));
  }

  /// Đường gửi ảnh dự phòng khi socket mất kết nối.
  Future<ChatMessage> sendImage(
    int conversationId,
    String imageUrl,
    String clientMsgId, {
    int? replyToId,
  }) async {
    final data = await _api.post(
      ApiConstants.chatMessagesUrl(conversationId),
      body: {
        'type': 'IMAGE',
        'imageUrl': imageUrl,
        'clientMsgId': clientMsgId,
        'replyToId': ?replyToId,
      },
    );
    return ChatMessage.fromJson(_map(data));
  }

  /// Tải ảnh lên Cloudinary qua backend, trả về URL.
  ///
  /// Backend chỉ nhận ảnh, video, âm thanh theo loại file khai báo, nên phải gửi kèm loại thật của ảnh
  /// (không khai báo thì `http` mặc định là application/octet-stream và bị từ chối).
  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final (type, extension) = imageTypeOf(bytes);
    final name = fileName.contains('.')
        ? '${fileName.substring(0, fileName.lastIndexOf('.'))}.$extension'
        : '$fileName.$extension';
    final response = await _api.sendMultipart(
      () =>
          http.MultipartRequest(
              'POST',
              Uri.parse(ApiConstants.chatImageUploadUrl),
            )
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: name,
                contentType: MediaType('image', type),
              ),
            ),
      timeout: const Duration(seconds: 60),
    );
    final data = _map(ApiClient.decodeResponse(response));
    return (data['secureUrl'] ?? data['url']).toString();
  }

  /// Nhận dạng định dạng ảnh theo nội dung file; không nhận ra thì coi là JPEG (ảnh chọn từ thư viện đã nén JPEG).
  /// Trả (subtype của image/*, đuôi file).
  static (String, String) imageTypeOf(Uint8List bytes) {
    bool starts(List<int> magic) =>
        bytes.length >= magic.length &&
        List.generate(magic.length, (i) => bytes[i] == magic[i]).every((e) => e);

    if (starts(const [0x89, 0x50, 0x4E, 0x47])) return ('png', 'png');
    if (starts(const [0x47, 0x49, 0x46, 0x38])) return ('gif', 'gif');
    // WebP: "RIFF" .... "WEBP"
    if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return ('webp', 'webp');
    }
    return ('jpeg', 'jpg');
  }

  Future<ChatMessage> recallMessage(int messageId) async {
    final data = await _api.post(ApiConstants.chatRecallUrl(messageId));
    return ChatMessage.fromJson(_map(data));
  }

  /// Bản dịch Nhật → Việt của một tin.
  Future<String> translateMessage(int messageId) async {
    final data = await _api.get(ApiConstants.chatTranslationUrl(messageId));
    return _map(data)['translation']?.toString() ?? '';
  }

  /// Xoá đoạn chat ở phía người dùng hiện tại.
  Future<void> deleteConversation(int conversationId) async {
    await _api.delete(ApiConstants.chatConversationUrl(conversationId));
  }

  Future<void> blockUser(int userId) async {
    await _api.post(ApiConstants.chatBlockUrl(userId));
  }

  Future<void> unblockUser(int userId) async {
    await _api.delete(ApiConstants.chatBlockUrl(userId));
  }

  /// Đăng ký token FCM để nhận thông báo đẩy.
  Future<void> registerDevice(String token, String platform) async {
    await _api.post(
      ApiConstants.chatDevicesUrl,
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> markRead(int conversationId, int lastMessageId) async {
    await _api.post(
      ApiConstants.chatReadUrl(conversationId),
      body: {'conversationId': conversationId, 'lastMessageId': lastMessageId},
    );
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get(ApiConstants.chatUnreadCountUrl);
    final count = data is Map<String, dynamic> ? data['count'] : 0;
    return count is num ? count.toInt() : 0;
  }

  /// Chia sẻ một bộ thẻ công khai cho nhiều người (người nhận phải follow lẫn nhau với mình).
  Future<void> shareDeck(
    int deckId, {
    required List<int> recipientIds,
    String? note,
  }) async {
    await _api.post(
      ApiConstants.shareDeckUrl(deckId),
      body: {
        'recipientIds': recipientIds,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  /// Chia sẻ video cho nhiều người; [startMs] để người nhận mở đúng câu phụ đề.
  Future<void> shareVideo(
    int videoId, {
    required List<int> recipientIds,
    String? note,
    int? startMs,
  }) async {
    await _api.post(
      ApiConstants.shareVideoUrl(videoId),
      body: {
        'recipientIds': recipientIds,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'startMs': ?startMs,
      },
    );
  }

  static List<Map<String, dynamic>> _list(dynamic data) =>
      data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Backend trả về dữ liệu chat không hợp lệ.');
  }
}
