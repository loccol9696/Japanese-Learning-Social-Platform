/// Các model của tính năng chat, khớp với DTO của backend (module `chat`).
library;

import 'dart:typed_data';

int _toInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

int? _toIntOrNull(dynamic value) => value == null
    ? null
    : (value is num ? value.toInt() : int.tryParse('$value'));

class ChatUser {
  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String? jlptLevel;

  const ChatUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.jlptLevel,
  });

  /// Tên hiển thị; rơi về username nếu chưa đặt.
  String get name => displayName.isNotEmpty ? displayName : username;

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: _toInt(json['id']),
    username: json['username']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
    jlptLevel: json['jlptLevel']?.toString(),
  );
}

enum MessageType { text, videoShare, image }

enum MessageStatus { sending, sent, failed }

/// Thẻ video trong tin nhắn chia sẻ. [available] = false khi video đã bị xoá
/// hoặc không còn công khai.
class SharedVideo {
  final int id;
  final bool available;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final int duration;
  final String? jlptLevel;
  final String creatorName;

  const SharedVideo({
    required this.id,
    required this.available,
    this.title = '',
    this.thumbnailUrl = '',
    this.videoUrl = '',
    this.duration = 0,
    this.jlptLevel,
    this.creatorName = '',
  });

  factory SharedVideo.fromJson(Map<String, dynamic> json) {
    final creatorDisplay = json['creatorDisplayName']?.toString() ?? '';
    return SharedVideo(
      id: _toInt(json['id']),
      available: json['available'] == true,
      title: json['title']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      duration: _toInt(json['duration']),
      jlptLevel: json['jlptLevel']?.toString(),
      creatorName: creatorDisplay.isNotEmpty
          ? creatorDisplay
          : '${json['creatorUsername'] ?? ''}',
    );
  }
}

MessageType _parseType(dynamic value) => switch (value) {
  'VIDEO_SHARE' => MessageType.videoShare,
  'IMAGE' => MessageType.image,
  _ => MessageType.text,
};

/// Trích dẫn của tin được trả lời.
class MessageReply {
  final int id;
  final int senderId;
  final MessageType type;
  final String content;
  final bool recalled;

  const MessageReply({
    required this.id,
    required this.senderId,
    required this.type,
    required this.content,
    this.recalled = false,
  });

  factory MessageReply.fromJson(Map<String, dynamic> json) => MessageReply(
    id: _toInt(json['id']),
    senderId: _toInt(json['senderId']),
    type: _parseType(json['type']),
    content: json['content']?.toString() ?? '',
    recalled: json['recalled'] == true,
  );

  factory MessageReply.of(ChatMessage message) => MessageReply(
    id: message.id!,
    senderId: message.senderId,
    type: message.type,
    content: message.content,
    recalled: message.recalled,
  );

  /// Dòng tóm tắt hiển thị trong trích dẫn.
  String get preview {
    if (recalled) return 'Tin nhắn đã được thu hồi';
    if (content.isNotEmpty) return content;
    return type == MessageType.image ? '📷 Ảnh' : '🎬 Video';
  }
}

class ChatMessage {
  /// null khi tin còn ở trạng thái đang gửi (chưa có id từ server).
  final int? id;
  final int conversationId;
  final int senderId;
  final MessageType type;
  final String content;
  final SharedVideo? video;
  final int? videoStartMs;

  /// URL ảnh (tin ảnh đã tải lên xong).
  final String imageUrl;

  /// Ảnh trên máy, chỉ có ở tin đang gửi để hiển thị trước khi tải lên xong.
  final Uint8List? localImage;

  /// Tin được trả lời (nếu có).
  final MessageReply? replyTo;

  /// Người gửi đã thu hồi: nội dung, video và ảnh không còn.
  final bool recalled;
  final String clientMsgId;
  final DateTime createdAt;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.clientMsgId,
    required this.createdAt,
    this.video,
    this.videoStartMs,
    this.imageUrl = '',
    this.localImage,
    this.replyTo,
    this.recalled = false,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({
    int? id,
    String? imageUrl,
    MessageReply? replyTo,
    MessageStatus? status,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId,
    senderId: senderId,
    type: type,
    content: content,
    video: video,
    videoStartMs: videoStartMs,
    imageUrl: imageUrl ?? this.imageUrl,
    localImage: localImage,
    replyTo: replyTo ?? this.replyTo,
    recalled: recalled,
    clientMsgId: clientMsgId,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final video = json['video'];
    final replyTo = json['replyTo'];
    return ChatMessage(
      id: _toIntOrNull(json['id']),
      conversationId: _toInt(json['conversationId']),
      senderId: _toInt(json['senderId']),
      type: _parseType(json['type']),
      content: json['content']?.toString() ?? '',
      video: video is Map<String, dynamic> ? SharedVideo.fromJson(video) : null,
      videoStartMs: _toIntOrNull(json['videoStartMs']),
      imageUrl: json['imageUrl']?.toString() ?? '',
      replyTo: replyTo is Map<String, dynamic>
          ? MessageReply.fromJson(replyTo)
          : null,
      recalled: json['recalled'] == true,
      clientMsgId: json['clientMsgId']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Tin tạm hiển thị ngay khi người dùng bấm gửi (optimistic UI).
  factory ChatMessage.pendingText({
    required int conversationId,
    required int senderId,
    required String content,
    required String clientMsgId,
    MessageReply? replyTo,
  }) => ChatMessage(
    id: null,
    conversationId: conversationId,
    senderId: senderId,
    type: MessageType.text,
    content: content,
    replyTo: replyTo,
    clientMsgId: clientMsgId,
    createdAt: DateTime.now(),
    status: MessageStatus.sending,
  );

  /// Tin ảnh tạm hiển thị ngay khi chọn ảnh, trong lúc đang tải lên.
  factory ChatMessage.pendingImage({
    required int conversationId,
    required int senderId,
    required Uint8List bytes,
    required String clientMsgId,
    MessageReply? replyTo,
  }) => ChatMessage(
    id: null,
    conversationId: conversationId,
    senderId: senderId,
    type: MessageType.image,
    content: '',
    localImage: bytes,
    replyTo: replyTo,
    clientMsgId: clientMsgId,
    createdAt: DateTime.now(),
    status: MessageStatus.sending,
  );

  /// Gợi ý ngắn gọn cho danh sách hội thoại.
  String previewFor(int myId) {
    final prefix = senderId == myId ? 'Bạn: ' : '';
    if (recalled) return '${prefix}Tin nhắn đã thu hồi';
    if (type == MessageType.image) return '$prefix📷 Ảnh';
    if (type == MessageType.videoShare) {
      final title = (video?.available ?? false) ? video!.title : 'Video';
      return '$prefix🎬 $title';
    }
    return '$prefix$content';
  }
}

class Conversation {
  final int id;
  final ChatUser otherUser;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int? otherLastReadMessageId;

  /// false khi hai bên không còn follow lẫn nhau hoặc một bên đã chặn: chỉ xem lại
  /// được lịch sử.
  final bool canMessage;

  /// Người đang xem đã chặn người kia.
  final bool blockedByMe;
  final DateTime? lastMessageAt;

  const Conversation({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.unreadCount,
    required this.otherLastReadMessageId,
    required this.canMessage,
    required this.lastMessageAt,
    this.blockedByMe = false,
  });

  Conversation copyWith({
    ChatMessage? lastMessage,
    int? unreadCount,
    int? otherLastReadMessageId,
    bool? canMessage,
    DateTime? lastMessageAt,
  }) => Conversation(
    id: id,
    otherUser: otherUser,
    lastMessage: lastMessage ?? this.lastMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    otherLastReadMessageId:
        otherLastReadMessageId ?? this.otherLastReadMessageId,
    canMessage: canMessage ?? this.canMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    blockedByMe: blockedByMe,
  );

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return Conversation(
      id: _toInt(json['id']),
      otherUser: ChatUser.fromJson(json['otherUser'] as Map<String, dynamic>),
      lastMessage: last is Map<String, dynamic>
          ? ChatMessage.fromJson(last)
          : null,
      unreadCount: _toInt(json['unreadCount']),
      otherLastReadMessageId: _toIntOrNull(json['otherLastReadMessageId']),
      canMessage: json['canMessage'] != false,
      blockedByMe: json['blockedByMe'] == true,
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
    );
  }
}

class MessagePage {
  /// Mới nhất trước (đúng thứ tự backend trả về).
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextCursor;

  const MessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    messages: (json['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(),
    hasMore: json['hasMore'] == true,
    nextCursor: _toIntOrNull(json['nextCursor']),
  );
}

class ReadReceipt {
  final int conversationId;
  final int userId;
  final int? lastReadMessageId;

  const ReadReceipt({
    required this.conversationId,
    required this.userId,
    required this.lastReadMessageId,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) => ReadReceipt(
    conversationId: _toInt(json['conversationId']),
    userId: _toInt(json['userId']),
    lastReadMessageId: _toIntOrNull(json['lastReadMessageId']),
  );
}

class TypingEvent {
  final int conversationId;
  final int userId;
  final bool isTyping;

  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) => TypingEvent(
    conversationId: _toInt(json['conversationId']),
    userId: _toInt(json['userId']),
    isTyping: json['isTyping'] == true,
  );
}
