package com.jlsp.backend.chat.service;

import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareVideoRequest;
import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.ReadReceiptResponse;
import com.jlsp.backend.common.response.PageResponse;
import org.springframework.data.domain.Pageable;

import java.util.List;

/**
 * Nghiệp vụ chat 1-1, dùng chung cho REST controller và Socket.IO gateway.
 * Chỉ hai người follow lẫn nhau mới được nhắn tin / chia sẻ video cho nhau.
 */
public interface ChatService {

    /** Những người có thể nhắn tin (follow lẫn nhau). */
    List<ChatUserResponse> getContacts(Long userId);

    PageResponse<ConversationResponse> getConversations(Long userId, Pageable pageable);

    ConversationResponse getOrCreateConversation(Long userId, Long recipientId);

    ConversationResponse getConversation(Long userId, Long conversationId);

    MessagePageResponse getMessages(Long userId, Long conversationId, Long beforeId, int size);

    /**
     * Các tin mới hơn {@code afterId}, cũ nhất trước. Client gọi lặp với {@code afterId = nextCursor}
     * đến khi hết để lấy đủ phần đã lỡ, dù offline bao lâu.
     */
    MessagePageResponse getMessagesAfter(Long userId, Long conversationId, Long afterId, int size);

    MessageResponse sendMessage(Long userId, SendMessageRequest request);

    List<MessageResponse> shareVideo(Long userId, Long videoId, ShareVideoRequest request);

    ReadReceiptResponse markAsRead(Long userId, Long conversationId, Long lastMessageId);

    long getUnreadCount(Long userId);

    /**
     * Xoá đoạn chat ở phía người này: toàn bộ tin hiện có bị ẩn với riêng họ, người kia vẫn
     * thấy đủ. Có tin mới thì hội thoại hiện lại, chỉ gồm các tin mới.
     */
    void clearConversation(Long userId, Long conversationId);

    /** Thu hồi tin của chính mình trong 24 giờ sau khi gửi; gọi lại trên tin đã thu hồi không có tác dụng. */
    MessageResponse recallMessage(Long userId, Long messageId);

    /** Nội dung cần dịch của một tin; ném lỗi nếu userId không thuộc hội thoại hoặc tin không có chữ. */
    String getTranslatableContent(Long userId, Long messageId);

    /** Chặn trong phạm vi chat: hai bên không nhắn tin được nữa, lịch sử vẫn còn. */
    void blockUser(Long userId, Long targetId);

    void unblockUser(Long userId, Long targetId);

    /**
     * ID người nhận sự kiện "đang nhập"; null nếu một trong hai bên đã chặn bên kia.
     * Ném lỗi nếu userId không thuộc hội thoại.
     */
    Long findTypingRecipientId(Long userId, Long conversationId);

    /** Lưu token nhận thông báo đẩy của thiết bị; token đã có thì gán lại cho người đang đăng nhập. */
    void registerDevice(Long userId, String token, String platform);

    void unregisterDevice(Long userId, String token);
}
