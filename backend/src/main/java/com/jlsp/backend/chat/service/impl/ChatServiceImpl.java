package com.jlsp.backend.chat.service.impl;

import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareVideoRequest;
import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.ReadReceiptResponse;
import com.jlsp.backend.chat.entity.Conversation;
import com.jlsp.backend.chat.entity.ConversationParticipant;
import com.jlsp.backend.chat.entity.ConversationParticipantId;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.event.ConversationReadEvent;
import com.jlsp.backend.chat.event.MessageCreatedEvent;
import com.jlsp.backend.chat.mapper.ChatMapper;
import com.jlsp.backend.chat.repository.ConversationParticipantRepository;
import com.jlsp.backend.chat.repository.ConversationRepository;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.service.ChatRateLimiter;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.FollowService;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.VideoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ChatServiceImpl implements ChatService {

    private static final int MAX_PAGE_SIZE = 50;

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository participantRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final FollowService followService;
    private final ChatMapper chatMapper;
    private final ChatRateLimiter rateLimiter;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    public List<ChatUserResponse> getContacts(Long userId) {
        return followService.getMutualFollows(userId).stream()
                .map(chatMapper::toUserResponse)
                .toList();
    }

    @Override
    public PageResponse<ConversationResponse> getConversations(Long userId, Pageable pageable) {
        Page<Conversation> page = conversationRepository.findActiveByUserId(userId, pageable);
        Map<Long, Video> videos = loadVideos(page.getContent().stream()
                .map(c -> c.getLastMessage())
                .filter(Objects::nonNull)
                .map(m -> m.getVideoId())
                .toList());
        return PageResponse.from(page.map(c -> toConversationResponse(c, userId, videos)));
    }

    @Override
    @Transactional
    public ConversationResponse getOrCreateConversation(Long userId, Long recipientId) {
        User recipient = ensureCanMessage(userId, recipientId);
        Conversation conversation = findOrCreateConversation(userId, recipient);
        return toConversationResponse(conversation, userId, loadVideosOf(conversation));
    }

    @Override
    public ConversationResponse getConversation(Long userId, Long conversationId) {
        Conversation conversation = requireConversation(userId, conversationId);
        return toConversationResponse(conversation, userId, loadVideosOf(conversation));
    }

    @Override
    public MessagePageResponse getMessages(Long userId, Long conversationId, Long beforeId, int size) {
        requireConversation(userId, conversationId);
        int pageSize = Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        // Lấy dư 1 bản ghi để biết còn tin cũ hơn hay không
        Pageable limit = PageRequest.of(0, pageSize + 1);
        List<Message> messages = beforeId == null
                ? messageRepository.findByConversationIdOrderByIdDesc(conversationId, limit)
                : messageRepository.findByConversationIdAndIdLessThanOrderByIdDesc(conversationId, beforeId, limit);

        boolean hasMore = messages.size() > pageSize;
        if (hasMore) {
            messages = messages.subList(0, pageSize);
        }
        Map<Long, Video> videos = loadVideos(messages.stream().map(m -> m.getVideoId()).toList());
        List<MessageResponse> content = messages.stream()
                .map(m -> chatMapper.toMessageResponse(m, videos))
                .toList();

        return MessagePageResponse.builder()
                .content(content)
                .hasMore(hasMore)
                .nextCursor(hasMore ? messages.get(messages.size() - 1).getId() : null)
                .build();
    }

    @Override
    @Transactional
    public MessageResponse sendMessage(Long userId, SendMessageRequest request) {
        // Gửi lại cùng clientMsgId (mạng chập chờn) → trả về tin đã lưu, không tạo bản sao
        if (request.getClientMsgId() != null && !request.getClientMsgId().isBlank()) {
            var existing = messageRepository.findBySenderIdAndClientMsgId(userId, request.getClientMsgId());
            if (existing.isPresent()) {
                Message message = existing.get();
                return chatMapper.toMessageResponse(message,
                        loadVideos(Collections.singletonList(message.getVideoId())));
            }
        }
        rateLimiter.check(userId);

        Conversation conversation;
        User recipient;
        if (request.getConversationId() != null) {
            conversation = requireConversation(userId, request.getConversationId());
            recipient = ensureCanMessage(userId, conversation.getOtherUser(userId).getId());
        } else if (request.getRecipientId() != null) {
            recipient = ensureCanMessage(userId, request.getRecipientId());
            conversation = findOrCreateConversation(userId, recipient);
        } else {
            throw new AppException(400, "Thiếu người nhận hoặc hội thoại");
        }
        return createMessage(userId, conversation, recipient, request);
    }

    @Override
    @Transactional
    public List<MessageResponse> shareVideo(Long userId, Long videoId, ShareVideoRequest request) {
        rateLimiter.check(userId);
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        if (!chatMapper.isShareable(video)) {
            throw new AppException(400, "Video này chưa thể chia sẻ");
        }

        // Kiểm tra toàn bộ người nhận trước để không gửi dở dang
        List<User> recipients = request.getRecipientIds().stream()
                .filter(Objects::nonNull)
                .distinct()
                .map(recipientId -> ensureCanMessage(userId, recipientId))
                .toList();

        SendMessageRequest message = SendMessageRequest.builder()
                .type(MessageType.VIDEO_SHARE)
                .content(request.getNote())
                .videoId(videoId)
                .videoStartMs(request.getStartMs())
                .build();

        List<MessageResponse> sent = new ArrayList<>();
        for (User recipient : recipients) {
            Conversation conversation = findOrCreateConversation(userId, recipient);
            sent.add(createMessage(userId, conversation, recipient, message));
        }
        log.info("User {} shared video {} to {} người", userId, videoId, sent.size());
        return sent;
    }

    @Override
    @Transactional
    public ReadReceiptResponse markAsRead(Long userId, Long conversationId, Long lastMessageId) {
        Conversation conversation = requireConversation(userId, conversationId);
        ConversationParticipant participant = getOrCreateParticipant(conversation, userId);

        Long latestId = messageRepository.findLatestId(conversationId);
        Long current = participant.getLastReadMessageId();
        if (latestId != null && lastMessageId != null) {
            long target = Math.min(lastMessageId, latestId);
            if (current == null || target > current) {
                participant.setLastReadMessageId(target);
                participantRepository.save(participant);

                ReadReceiptResponse receipt = buildReceipt(conversationId, userId, target);
                eventPublisher.publishEvent(new ConversationReadEvent(receipt,
                        conversation.getOtherUser(userId).getId()));
                return receipt;
            }
        }
        return buildReceipt(conversationId, userId, current);
    }

    @Override
    public long getUnreadCount(Long userId) {
        return participantRepository.countUnreadMessages(userId);
    }

    @Override
    public Long getOtherParticipantId(Long userId, Long conversationId) {
        return requireConversation(userId, conversationId).getOtherUser(userId).getId();
    }

    // -------------------------------------------------------------------------
    // Nội bộ
    // -------------------------------------------------------------------------

    private MessageResponse createMessage(Long senderId, Conversation conversation, User recipient,
                                          SendMessageRequest request) {
        String content = request.getContent() == null ? null : request.getContent().strip();
        Video video = null;

        if (request.getType() == MessageType.TEXT) {
            if (content == null || content.isEmpty()) {
                throw new AppException(400, "Tin nhắn không được để trống");
            }
        } else if (request.getType() == MessageType.VIDEO_SHARE) {
            if (request.getVideoId() == null) {
                throw new AppException(400, "Thiếu video cần chia sẻ");
            }
            video = videoRepository.findById(request.getVideoId())
                    .orElseThrow(() -> new ResourceNotFoundException("Video", "id", request.getVideoId()));
            if (!chatMapper.isShareable(video)) {
                throw new AppException(400, "Video này chưa thể chia sẻ");
            }
            if (content != null && content.isEmpty()) {
                content = null;
            }
        } else {
            throw new AppException(400, "Loại tin nhắn không hợp lệ");
        }

        Message message = messageRepository.save(Message.builder()
                .conversation(conversation)
                .sender(userRepository.getReferenceById(senderId))
                .type(request.getType())
                .content(content)
                .videoId(video != null ? video.getId() : null)
                .videoStartMs(video != null ? request.getVideoStartMs() : null)
                .clientMsgId(request.getClientMsgId() == null || request.getClientMsgId().isBlank()
                        ? null : request.getClientMsgId())
                .build());

        conversation.setLastMessage(message);
        conversation.setLastMessageAt(message.getCreatedAt());
        conversationRepository.save(conversation);

        // Tin của chính mình luôn được tính là đã đọc
        ConversationParticipant senderState = getOrCreateParticipant(conversation, senderId);
        senderState.setLastReadMessageId(message.getId());
        participantRepository.save(senderState);

        Map<Long, Video> videos = video != null ? Map.of(video.getId(), video) : Map.of();
        MessageResponse response = chatMapper.toMessageResponse(message, videos);
        eventPublisher.publishEvent(new MessageCreatedEvent(response, senderId, recipient.getId()));
        return response;
    }

    /**
     * Người nhận phải tồn tại, đang hoạt động và hai bên follow lẫn nhau.
     */
    private User ensureCanMessage(Long userId, Long recipientId) {
        if (userId.equals(recipientId)) {
            throw new AppException(400, "Không thể nhắn tin cho chính mình");
        }
        User recipient = userRepository.findById(recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", recipientId));
        if (!Boolean.TRUE.equals(recipient.getIsActive())) {
            throw new AppException(400, "Tài khoản này đã bị khóa");
        }
        if (!followService.isMutual(userId, recipientId)) {
            throw new AppException(403, "Hai bạn cần theo dõi lẫn nhau để nhắn tin");
        }
        return recipient;
    }

    private Conversation findOrCreateConversation(Long userId, User other) {
        Long lowId = Math.min(userId, other.getId());
        Long highId = Math.max(userId, other.getId());
        return conversationRepository.findByUserLowIdAndUserHighId(lowId, highId)
                .orElseGet(() -> {
                    User me = userRepository.getReferenceById(userId);
                    Conversation conversation = conversationRepository.save(Conversation.builder()
                            .userLow(lowId.equals(userId) ? me : other)
                            .userHigh(lowId.equals(userId) ? other : me)
                            .build());
                    getOrCreateParticipant(conversation, userId);
                    getOrCreateParticipant(conversation, other.getId());
                    log.info("Tạo hội thoại {} giữa user {} và user {}", conversation.getId(), lowId, highId);
                    return conversation;
                });
    }

    private ConversationParticipant getOrCreateParticipant(Conversation conversation, Long userId) {
        ConversationParticipantId id = new ConversationParticipantId(conversation.getId(), userId);
        return participantRepository.findById(id)
                .orElseGet(() -> participantRepository.save(ConversationParticipant.builder()
                        .id(id)
                        .conversation(conversation)
                        .user(userRepository.getReferenceById(userId))
                        .build()));
    }

    private Conversation requireConversation(Long userId, Long conversationId) {
        Conversation conversation = conversationRepository.findDetailById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation", "id", conversationId));
        if (!conversation.getUserLow().getId().equals(userId) && !conversation.getUserHigh().getId().equals(userId)) {
            throw new AppException(403, "Bạn không thuộc hội thoại này");
        }
        return conversation;
    }

    private ConversationResponse toConversationResponse(Conversation conversation, Long userId,
                                                        Map<Long, Video> videos) {
        User other = conversation.getOtherUser(userId);
        Long myLastRead = participantRepository
                .findById(new ConversationParticipantId(conversation.getId(), userId))
                .map(p -> p.getLastReadMessageId())
                .orElse(null);
        Long otherLastRead = participantRepository
                .findById(new ConversationParticipantId(conversation.getId(), other.getId()))
                .map(p -> p.getLastReadMessageId())
                .orElse(null);

        return ConversationResponse.builder()
                .id(conversation.getId())
                .otherUser(chatMapper.toUserResponse(other))
                .lastMessage(chatMapper.toMessageResponse(conversation.getLastMessage(), videos))
                .unreadCount(messageRepository.countUnread(conversation.getId(), userId,
                        myLastRead != null ? myLastRead : 0L))
                .otherLastReadMessageId(otherLastRead)
                .canMessage(Boolean.TRUE.equals(other.getIsActive()) && followService.isMutual(userId, other.getId()))
                .lastMessageAt(conversation.getLastMessageAt())
                .build();
    }

    private Map<Long, Video> loadVideosOf(Conversation conversation) {
        Message last = conversation.getLastMessage();
        return last == null ? Map.of() : loadVideos(Collections.singletonList(last.getVideoId()));
    }

    private Map<Long, Video> loadVideos(Collection<Long> videoIds) {
        List<Long> ids = videoIds.stream().filter(Objects::nonNull).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }
        return videoRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(v -> v.getId(), Function.identity()));
    }

    private static ReadReceiptResponse buildReceipt(Long conversationId, Long userId, Long lastReadMessageId) {
        return ReadReceiptResponse.builder()
                .conversationId(conversationId)
                .userId(userId)
                .lastReadMessageId(lastReadMessageId)
                .build();
    }
}
