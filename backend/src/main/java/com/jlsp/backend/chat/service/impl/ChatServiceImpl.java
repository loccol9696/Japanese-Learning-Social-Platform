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
import com.jlsp.backend.chat.entity.DeviceToken;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.entity.UserBlock;
import com.jlsp.backend.chat.entity.UserBlockId;
import com.jlsp.backend.chat.event.ConversationClearedEvent;
import com.jlsp.backend.chat.event.ConversationReadEvent;
import com.jlsp.backend.chat.event.MessageCreatedEvent;
import com.jlsp.backend.chat.event.MessageRecalledEvent;
import com.jlsp.backend.chat.mapper.ChatMapper;
import com.jlsp.backend.chat.repository.ConversationParticipantRepository;
import com.jlsp.backend.chat.repository.ConversationRepository;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.repository.UserBlockRepository;
import com.jlsp.backend.chat.service.ChatImageValidator;
import com.jlsp.backend.chat.service.ChatRateLimiter;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
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

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ChatServiceImpl implements ChatService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final Duration RECALL_WINDOW = Duration.ofHours(24);

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository participantRepository;
    private final MessageRepository messageRepository;
    private final UserBlockRepository userBlockRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final FollowService followService;
    private final ChatMapper chatMapper;
    private final ChatRateLimiter rateLimiter;
    private final ChatImageValidator imageValidator;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    public List<ChatUserResponse> getContacts(Long userId) {
        Set<Long> blocked = new HashSet<>(userBlockRepository.findRelatedUserIds(userId));
        return followService.getMutualFollows(userId).stream()
                .filter(user -> !blocked.contains(user.getId()))
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
        InboxState state = loadInboxState(userId, page.getContent());
        return PageResponse.from(page.map(c -> toConversationResponse(c, userId, videos, state)));
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
        long floorId = clearedMessageId(conversationId, userId);
        int pageSize = Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        // Lấy dư 1 bản ghi để biết còn tin cũ hơn hay không
        Pageable limit = PageRequest.of(0, pageSize + 1);
        List<Message> messages = beforeId == null
                ? messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(conversationId, floorId, limit)
                : messageRepository.findByConversationIdAndIdGreaterThanAndIdLessThanOrderByIdDesc(
                        conversationId, floorId, beforeId, limit);

        boolean hasMore = messages.size() > pageSize;
        if (hasMore) {
            messages = messages.subList(0, pageSize);
        }
        return MessagePageResponse.builder()
                .content(toMessageResponses(messages))
                .hasMore(hasMore)
                .nextCursor(hasMore ? messages.get(messages.size() - 1).getId() : null)
                .build();
    }

    @Override
    public MessagePageResponse getMessagesAfter(Long userId, Long conversationId, Long afterId, int size) {
        requireConversation(userId, conversationId);
        int pageSize = Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        long floorId = Math.max(afterId == null ? 0L : afterId, clearedMessageId(conversationId, userId));
        // Lấy dư 1 bản ghi để biết còn tin mới hơn nữa hay không
        List<Message> messages = messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                conversationId, floorId, PageRequest.of(0, pageSize + 1));

        boolean hasMore = messages.size() > pageSize;
        if (hasMore) {
            messages = messages.subList(0, pageSize);
        }
        return MessagePageResponse.builder()
                .content(toMessageResponses(messages))
                .hasMore(hasMore)
                // Tin mới nhất của trang này, dùng làm afterId cho lần gọi kế tiếp
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
        notifyOwnerOfShare(video, userId, recipients);
        return sent;
    }

    /**
     * Báo cho chủ video biết video được chia sẻ. Một lần chia sẻ cho nhiều người chỉ tạo một
     * thông báo và không nêu người nhận. Bỏ qua khi người nhận duy nhất chính là chủ video,
     * vì họ đã nhận được tin nhắn chứa video đó.
     */
    private void notifyOwnerOfShare(Video video, Long sharerId, List<User> recipients) {
        Long ownerId = video.getUser().getId();
        boolean onlyOwnerReceived = recipients.size() == 1 && recipients.get(0).getId().equals(ownerId);
        if (!onlyOwnerReceived) {
            eventPublisher.publishEvent(NotificationRequestedEvent.shared(ownerId, sharerId, video.getId()));
        }
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
    @Transactional
    public void clearConversation(Long userId, Long conversationId) {
        Conversation conversation = requireConversation(userId, conversationId);
        Long latestId = messageRepository.findLatestId(conversationId);
        if (latestId == null) {
            return;
        }
        // Không đổi mốc đã đọc: xoá mà chưa đọc thì người kia không thấy "Đã xem".
        ConversationParticipant participant = getOrCreateParticipant(conversation, userId);
        participant.setClearedMessageId(latestId);
        participantRepository.save(participant);
        eventPublisher.publishEvent(new ConversationClearedEvent(conversationId, userId));
    }

    @Override
    @Transactional
    public MessageResponse recallMessage(Long userId, Long messageId) {
        Message message = requireMessage(messageId);
        Conversation conversation = requireConversation(userId, message.getConversation().getId());
        if (!message.getSender().getId().equals(userId)) {
            throw new AppException(403, "Bạn chỉ có thể thu hồi tin nhắn của mình");
        }
        if (message.getRecalledAt() != null) {
            return chatMapper.toMessageResponse(message, Map.of());
        }
        if (message.getCreatedAt().plus(RECALL_WINDOW).isBefore(LocalDateTime.now())) {
            throw new AppException(400, "Tin nhắn đã quá 24 giờ nên không thể thu hồi");
        }

        message.setRecalledAt(LocalDateTime.now());
        message.setContent(null);
        message.setVideoId(null);
        message.setVideoStartMs(null);
        message.setImageUrl(null);
        message.setReplyTo(null);
        messageRepository.save(message);

        MessageResponse response = chatMapper.toMessageResponse(message, Map.of());
        eventPublisher.publishEvent(new MessageRecalledEvent(response, userId,
                conversation.getOtherUser(userId).getId()));
        return response;
    }

    @Override
    public String getTranslatableContent(Long userId, Long messageId) {
        Message message = requireMessage(messageId);
        requireConversation(userId, message.getConversation().getId());
        if (message.getContent() == null || message.getContent().isBlank()) {
            throw new AppException(400, "Tin nhắn này không có nội dung để dịch");
        }
        return message.getContent();
    }

    @Override
    @Transactional
    public void blockUser(Long userId, Long targetId) {
        if (userId.equals(targetId)) {
            throw new AppException(400, "Không thể tự chặn chính mình");
        }
        User target = userRepository.findById(targetId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", targetId));
        UserBlockId id = new UserBlockId(userId, targetId);
        if (!userBlockRepository.existsById(id)) {
            userBlockRepository.save(UserBlock.builder()
                    .id(id)
                    .blocker(userRepository.getReferenceById(userId))
                    .blocked(target)
                    .build());
        }
    }

    @Override
    @Transactional
    public void unblockUser(Long userId, Long targetId) {
        UserBlockId id = new UserBlockId(userId, targetId);
        if (userBlockRepository.existsById(id)) {
            userBlockRepository.deleteById(id);
        }
    }

    @Override
    public Long findTypingRecipientId(Long userId, Long conversationId) {
        Long otherId = requireConversation(userId, conversationId).getOtherUser(userId).getId();
        return userBlockRepository.existsBetween(userId, otherId) ? null : otherId;
    }

    @Override
    @Transactional
    public void registerDevice(Long userId, String token, String platform) {
        User user = userRepository.getReferenceById(userId);
        DeviceToken device = deviceTokenRepository.findByToken(token)
                .orElseGet(() -> DeviceToken.builder().token(token).build());
        device.setUser(user);
        device.setPlatform(platform);
        deviceTokenRepository.save(device);
    }

    @Override
    @Transactional
    public void unregisterDevice(Long userId, String token) {
        deviceTokenRepository.deleteByUserIdAndToken(userId, token);
    }

    // -------------------------------------------------------------------------
    // Nội bộ
    // -------------------------------------------------------------------------

    private MessageResponse createMessage(Long senderId, Conversation conversation, User recipient,
                                          SendMessageRequest request) {
        String content = request.getContent() == null ? null : request.getContent().strip();
        Video video = null;
        String imageUrl = null;

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
        } else if (request.getType() == MessageType.IMAGE) {
            if (!imageValidator.isValid(request.getImageUrl())) {
                throw new AppException(400, "Ảnh không hợp lệ");
            }
            imageUrl = request.getImageUrl();
            if (content != null && content.isEmpty()) {
                content = null;
            }
        } else {
            throw new AppException(400, "Loại tin nhắn không hợp lệ");
        }

        Message replyTo = resolveReplyTarget(conversation, request.getReplyToId());

        Message message = messageRepository.save(Message.builder()
                .conversation(conversation)
                .sender(userRepository.getReferenceById(senderId))
                .type(request.getType())
                .content(content)
                .videoId(video != null ? video.getId() : null)
                .videoStartMs(video != null ? request.getVideoStartMs() : null)
                .imageUrl(imageUrl)
                .replyTo(replyTo)
                .clientMsgId(request.getClientMsgId() == null || request.getClientMsgId().isBlank()
                        ? null : request.getClientMsgId())
                .build());

        conversation.setLastMessage(message);
        conversation.setLastMessageAt(message.getCreatedAt());
        conversationRepository.save(conversation);

        // Tin của chính mình luôn được tính là đã đọc. Dùng UPDATE trực tiếp (1 lượt gọi DB)
        // thay vì nạp participant rồi lưu lại; chỉ tạo mới khi bản ghi chưa tồn tại.
        if (participantRepository.updateLastReadMessageId(conversation.getId(), senderId, message.getId()) == 0) {
            ConversationParticipant senderState = getOrCreateParticipant(conversation, senderId);
            senderState.setLastReadMessageId(message.getId());
            participantRepository.save(senderState);
        }

        Map<Long, Video> videos = video != null ? Map.of(video.getId(), video) : Map.of();
        MessageResponse response = chatMapper.toMessageResponse(message, videos);
        eventPublisher.publishEvent(new MessageCreatedEvent(response, senderId, recipient.getId()));
        return response;
    }

    /**
     * Cả hai tài khoản phải đang hoạt động, follow lẫn nhau và không ai chặn ai. Kiểm tra cả
     * người gửi vì socket chỉ xác thực lúc kết nối, tài khoản bị khoá sau đó vẫn còn kết nối.
     */
    private User ensureCanMessage(Long userId, Long recipientId) {
        if (userId.equals(recipientId)) {
            throw new AppException(400, "Không thể nhắn tin cho chính mình");
        }
        boolean senderActive = userRepository.findById(userId)
                .map(user -> Boolean.TRUE.equals(user.getIsActive()))
                .orElse(false);
        if (!senderActive) {
            throw new AppException(403, "Tài khoản của bạn đã bị khóa");
        }
        User recipient = userRepository.findById(recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", recipientId));
        if (!Boolean.TRUE.equals(recipient.getIsActive())) {
            throw new AppException(400, "Tài khoản này đã bị khóa");
        }
        if (!followService.isMutual(userId, recipientId)) {
            throw new AppException(403, "Hai bạn cần theo dõi lẫn nhau để nhắn tin");
        }
        if (userBlockRepository.existsBetween(userId, recipientId)) {
            throw new AppException(403, "Không thể nhắn tin cho người này");
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

    private long clearedMessageId(Long conversationId, Long userId) {
        return participantRepository.findById(new ConversationParticipantId(conversationId, userId))
                .map(participant -> participant.getClearedMessageId())
                .orElse(0L);
    }

    private Conversation requireConversation(Long userId, Long conversationId) {
        Conversation conversation = conversationRepository.findDetailById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation", "id", conversationId));
        if (!conversation.getUserLow().getId().equals(userId) && !conversation.getUserHigh().getId().equals(userId)) {
            throw new AppException(403, "Bạn không thuộc hội thoại này");
        }
        return conversation;
    }

    private Message resolveReplyTarget(Conversation conversation, Long replyToId) {
        if (replyToId == null) {
            return null;
        }
        Message target = requireMessage(replyToId);
        if (!target.getConversation().getId().equals(conversation.getId())) {
            throw new AppException(400, "Tin nhắn được trả lời không thuộc hội thoại này");
        }
        if (target.getRecalledAt() != null) {
            throw new AppException(400, "Tin nhắn này đã được thu hồi");
        }
        return target;
    }

    private Message requireMessage(Long messageId) {
        return messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message", "id", messageId));
    }

    private ConversationResponse toConversationResponse(Conversation conversation, Long userId,
                                                        Map<Long, Video> videos) {
        return toConversationResponse(conversation, userId, videos,
                loadInboxState(userId, List.of(conversation)));
    }

    private ConversationResponse toConversationResponse(Conversation conversation, Long userId,
                                                        Map<Long, Video> videos, InboxState state) {
        User other = conversation.getOtherUser(userId);
        Long otherLastRead = state.lastReadIds()
                .get(new ConversationParticipantId(conversation.getId(), other.getId()));
        Message last = conversation.getLastMessage();
        boolean lastCleared = last != null
                && last.getId() <= state.clearedIds().getOrDefault(conversation.getId(), 0L);

        return ConversationResponse.builder()
                .id(conversation.getId())
                .otherUser(chatMapper.toUserResponse(other))
                .lastMessage(lastCleared ? null : chatMapper.toMessageResponse(last, videos))
                .unreadCount(state.unreadCounts().getOrDefault(conversation.getId(), 0L))
                .otherLastReadMessageId(otherLastRead)
                .canMessage(Boolean.TRUE.equals(other.getIsActive())
                        && state.mutualIds().contains(other.getId())
                        && !state.blockedIds().contains(other.getId()))
                .blockedByMe(state.blockedByMeIds().contains(other.getId()))
                .lastMessageAt(conversation.getLastMessageAt())
                .build();
    }

    /**
     * Mốc đã đọc, số tin chưa đọc, quyền nhắn tin và trạng thái chặn của cả trang hội thoại:
     * 4 truy vấn gộp thay vì nhiều truy vấn cho MỖI hội thoại.
     */
    private InboxState loadInboxState(Long userId, List<Conversation> conversations) {
        if (conversations.isEmpty()) {
            return new InboxState(Map.of(), Map.of(), Map.of(), Set.of(), Set.of(), Set.of());
        }
        List<Long> conversationIds = conversations.stream().map(conversation -> conversation.getId()).toList();
        Map<ConversationParticipantId, Long> lastReadIds = new HashMap<>();
        Map<Long, Long> clearedIds = new HashMap<>();
        for (ConversationParticipant participant : participantRepository.findByIdConversationIdIn(conversationIds)) {
            if (participant.getLastReadMessageId() != null) {
                lastReadIds.put(participant.getId(), participant.getLastReadMessageId());
            }
            if (participant.getClearedMessageId() != null && participant.getId().getUserId().equals(userId)) {
                clearedIds.put(participant.getId().getConversationId(), participant.getClearedMessageId());
            }
        }
        Map<Long, Long> unreadCounts = IdCount.toMap(
                messageRepository.countUnreadByConversation(userId, conversationIds));
        List<Long> otherIds = conversations.stream()
                .map(c -> c.getOtherUser(userId).getId())
                .distinct()
                .toList();
        Set<Long> blockedIds = new HashSet<>();
        Set<Long> blockedByMeIds = new HashSet<>();
        for (UserBlock block : userBlockRepository.findBetween(userId, otherIds)) {
            boolean byMe = block.getId().getBlockerId().equals(userId);
            blockedIds.add(byMe ? block.getId().getBlockedId() : block.getId().getBlockerId());
            if (byMe) {
                blockedByMeIds.add(block.getId().getBlockedId());
            }
        }
        return new InboxState(lastReadIds, clearedIds, unreadCounts,
                followService.findMutualIdsAmong(userId, otherIds),
                blockedIds, blockedByMeIds);
    }

    private record InboxState(Map<ConversationParticipantId, Long> lastReadIds,
                              Map<Long, Long> clearedIds,
                              Map<Long, Long> unreadCounts,
                              Set<Long> mutualIds,
                              Set<Long> blockedIds,
                              Set<Long> blockedByMeIds) {
    }

    private List<MessageResponse> toMessageResponses(List<Message> messages) {
        Map<Long, Video> videos = loadVideos(messages.stream().map(m -> m.getVideoId()).toList());
        return messages.stream()
                .map(m -> chatMapper.toMessageResponse(m, videos))
                .toList();
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
