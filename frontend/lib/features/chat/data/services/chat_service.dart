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

  Future<MessagePage> fetchMessages(
    int conversationId, {
    int? before,
    int size = 30,
  }) async {
    final query = 'size=$size${before != null ? '&before=$before' : ''}';
    final data = await _api.get(
      '${ApiConstants.chatMessagesUrl(conversationId)}?$query',
    );
    return MessagePage.fromJson(_map(data));
  }

  /// Đường gửi dự phòng khi socket mất kết nối.
  Future<ChatMessage> sendText(
    int conversationId,
    String content,
    String clientMsgId,
  ) async {
    final data = await _api.post(
      ApiConstants.chatMessagesUrl(conversationId),
      body: {'type': 'TEXT', 'content': content, 'clientMsgId': clientMsgId},
    );
    return ChatMessage.fromJson(_map(data));
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
