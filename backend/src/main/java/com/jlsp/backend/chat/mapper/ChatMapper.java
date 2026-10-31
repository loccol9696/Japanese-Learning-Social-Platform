package com.jlsp.backend.chat.mapper;

import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.SharedDeckResponse;
import com.jlsp.backend.chat.dto.response.ReplyPreviewResponse;
import com.jlsp.backend.chat.dto.response.SharedVideoResponse;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.flashcard.entity.FlashcardSet;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class ChatMapper {

    private static final int MAX_REPLY_PREVIEW_LENGTH = 120;

    public ChatUserResponse toUserResponse(User user) {
        if (user == null) {
            return null;
        }
        return ChatUserResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .jlptLevel(user.getJlptLevel())
                .build();
    }

    public MessageResponse toMessageResponse(Message message, Map<Long, Video> videos) {
        return toMessageResponse(message, videos, Map.of());
    }

    /**
     * @param videos video đã tải sẵn theo id (tránh truy vấn từng tin nhắn)
     * @param decks  thẻ bộ từ vựng đã dựng sẵn theo id (cũng để tránh truy vấn từng tin nhắn)
     */
    public MessageResponse toMessageResponse(Message message, Map<Long, Video> videos,
                                             Map<Long, SharedDeckResponse> decks) {
        if (message == null) {
            return null;
        }
        SharedDeckResponse deck = message.getDeckId() == null
                ? null
                : decks.getOrDefault(message.getDeckId(), toSharedDeckResponse(message.getDeckId(), null, 0));
        SharedVideoResponse video = message.getVideoId() == null
                ? null
                : toSharedVideoResponse(message.getVideoId(), videos.get(message.getVideoId()));
        return MessageResponse.builder()
                .id(message.getId())
                .conversationId(message.getConversation().getId())
                .senderId(message.getSender().getId())
                .type(message.getType())
                .content(message.getContent())
                .video(video)
                .deck(deck)
                .videoStartMs(message.getVideoStartMs())
                .imageUrl(message.getImageUrl())
                .replyTo(toReplyPreview(message.getReplyTo()))
                .recalled(message.getRecalledAt() != null)
                .clientMsgId(message.getClientMsgId())
                .createdAt(message.getCreatedAt())
                .build();
    }

    private ReplyPreviewResponse toReplyPreview(Message reply) {
        if (reply == null) {
            return null;
        }
        String content = reply.getContent();
        return ReplyPreviewResponse.builder()
                .id(reply.getId())
                .senderId(reply.getSender().getId())
                .type(reply.getType())
                .content(content != null && content.length() > MAX_REPLY_PREVIEW_LENGTH
                        ? content.substring(0, MAX_REPLY_PREVIEW_LENGTH)
                        : content)
                .recalled(reply.getRecalledAt() != null)
                .build();
    }

    public SharedVideoResponse toSharedVideoResponse(Long videoId, Video video) {
        if (!isShareable(video)) {
            return SharedVideoResponse.builder().id(videoId).available(false).build();
        }
        User creator = video.getUser();
        return SharedVideoResponse.builder()
                .id(video.getId())
                .available(true)
                .title(video.getTitle())
                .thumbnailUrl(video.getThumbnailUrl())
                .videoUrl(video.getVideoUrl())
                .duration(video.getDuration())
                .jlptLevel(video.getJlptLevel())
                .creatorId(creator != null ? creator.getId() : null)
                .creatorUsername(creator != null ? creator.getUsername() : null)
                .creatorDisplayName(creator != null ? creator.getDisplayName() : null)
                .creatorAvatarUrl(creator != null ? creator.getAvatarUrl() : null)
                .build();
    }

    public SharedDeckResponse toSharedDeckResponse(Long deckId, FlashcardSet deck, long cardCount) {
        if (!isShareable(deck)) {
            return SharedDeckResponse.builder().id(deckId).available(false).build();
        }
        return SharedDeckResponse.builder()
                .id(deck.getSetId())
                .available(true)
                .title(deck.getTitle())
                .cardCount((int) cardCount)
                .build();
    }

    /** Chỉ bộ thẻ công khai mới được chia sẻ / hiển thị trong chat (người nhận chỉ đọc được bộ công khai). */
    public boolean isShareable(FlashcardSet deck) {
        return deck != null && Boolean.TRUE.equals(deck.getIsPublic());
    }

    /** Chỉ video đã được duyệt và không ở chế độ riêng tư mới được chia sẻ / hiển thị trong chat. */
    public boolean isShareable(Video video) {
        return video != null
                && video.getModStatus() == VideoModStatus.APPROVED
                && video.getStatus() != VideoStatus.PRIVATE;
    }
}
