package com.jlsp.backend.chat.service;

import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareDeckRequest;
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

    /**
     * Xoá cuộc trò chuyện chỉ ở phía người dùng: ẩn toàn bộ tin hiện có và đưa hội thoại ra khỏi hộp thư,
     * hội thoại hiện lại (chỉ với tin mới) khi có tin nhắn mới. Người kia vẫn giữ nguyên lịch sử.
     */
    void clearConversation(Long userId, Long conversationId);

    List<MessageResponse> shareVideo(Long userId, Long videoId, ShareVideoRequest request);

    /** Chia sẻ một bộ thẻ công khai cho nhiều người (follow lẫn nhau); mỗi người nhận một tin DECK_SHARE. */
    List<MessageResponse> shareDeck(Long userId, Long deckId, ShareDeckRequest request);

    ReadReceiptResponse markAsRead(Long userId, Long conversationId, Long lastMessageId);

    long getUnreadCount(Long userId);

    /** ID người còn lại trong hội thoại; ném lỗi nếu userId không thuộc hội thoại. */
    Long getOtherParticipantId(Long userId, Long conversationId);
}
