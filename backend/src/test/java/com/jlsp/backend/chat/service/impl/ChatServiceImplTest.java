package com.jlsp.backend.chat.service.impl;

import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareVideoRequest;
import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.entity.Conversation;
import com.jlsp.backend.chat.entity.ConversationParticipant;
import com.jlsp.backend.chat.entity.ConversationParticipantId;
import com.jlsp.backend.chat.entity.DeviceToken;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.entity.UserBlock;
import com.jlsp.backend.chat.entity.UserBlockId;
import com.jlsp.backend.chat.event.ConversationClearedEvent;
import com.jlsp.backend.chat.event.MessageRecalledEvent;
import com.jlsp.backend.chat.mapper.ChatMapper;
import com.jlsp.backend.chat.repository.ConversationParticipantRepository;
import com.jlsp.backend.chat.repository.ConversationRepository;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.repository.UserBlockRepository;
import com.jlsp.backend.chat.service.ChatImageValidator;
import com.jlsp.backend.chat.service.ChatRateLimiter;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.FollowService;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ChatServiceImplTest {

    private static final long CONVERSATION_ID = 10L;
    private static final long ME = 1L;
    private static final long OTHER = 2L;

    private MessageRepository messageRepository;
    private ConversationRepository conversationRepository;
    private UserBlockRepository userBlockRepository;
    private DeviceTokenRepository deviceTokenRepository;
    private ConversationParticipantRepository participantRepository;
    private UserRepository userRepository;
    private VideoRepository videoRepository;
    private FollowService followService;
    private ApplicationEventPublisher eventPublisher;
    private ChatServiceImpl service;
    private Conversation conversation;
    private User me;
    private User other;

    @BeforeEach
    void setUp() {
        conversationRepository = mock(ConversationRepository.class);
        messageRepository = mock(MessageRepository.class);
        userBlockRepository = mock(UserBlockRepository.class);
        deviceTokenRepository = mock(DeviceTokenRepository.class);
        participantRepository = mock(ConversationParticipantRepository.class);
        userRepository = mock(UserRepository.class);
        videoRepository = mock(VideoRepository.class);
        followService = mock(FollowService.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        service = new ChatServiceImpl(
                conversationRepository,
                participantRepository,
                messageRepository,
                userBlockRepository,
                deviceTokenRepository,
                userRepository,
                videoRepository,
                followService,
                new ChatMapper(),
                new ChatRateLimiter(),
                new ChatImageValidator("demo"),
                eventPublisher);

        me = User.builder().id(ME).isActive(true).build();
        other = User.builder().id(OTHER).isActive(true).build();
        conversation = Conversation.builder().id(CONVERSATION_ID).userLow(me).userHigh(other).build();
        when(conversationRepository.findDetailById(CONVERSATION_ID)).thenReturn(Optional.of(conversation));
        when(userRepository.findById(ME)).thenReturn(Optional.of(me));
        when(userRepository.findById(OTHER)).thenReturn(Optional.of(other));
        when(followService.isMutual(ME, OTHER)).thenReturn(true);
        when(messageRepository.save(any(Message.class))).thenAnswer(call -> {
            Message saved = call.getArgument(0);
            saved.setId(100L);
            return saved;
        });
    }

    @Test
    void messagesAfterAreOldestFirstWithCursorWhenMoreRemain() {
        // size = 2 → server lấy dư 1 bản ghi (3) để biết còn tin hay không
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(5L), any(Pageable.class)))
                .thenReturn(List.of(message(6L), message(7L), message(8L)));

        MessagePageResponse page = service.getMessagesAfter(ME, CONVERSATION_ID, 5L, 2);

        assertThat(page.getContent()).extracting(m -> m.getId()).containsExactly(6L, 7L);
        assertThat(page.getHasMore()).isTrue();
        assertThat(page.getNextCursor()).isEqualTo(7L);

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(messageRepository).findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(5L), pageable.capture());
        assertThat(pageable.getValue().getPageSize()).isEqualTo(3);
    }

    @Test
    void lastPageHasNoMoreAndNoCursor() {
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(5L), any(Pageable.class)))
                .thenReturn(List.of(message(6L), message(7L)));

        MessagePageResponse page = service.getMessagesAfter(ME, CONVERSATION_ID, 5L, 30);

        assertThat(page.getContent()).hasSize(2);
        assertThat(page.getHasMore()).isFalse();
        assertThat(page.getNextCursor()).isNull();
    }

    @Test
    void missingCursorStartsFromTheBeginning() {
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(0L), any(Pageable.class)))
                .thenReturn(List.of());

        MessagePageResponse page = service.getMessagesAfter(ME, CONVERSATION_ID, null, 30);

        assertThat(page.getContent()).isEmpty();
        assertThat(page.getHasMore()).isFalse();
        verify(messageRepository).findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(0L), any(Pageable.class));
    }

    @Test
    void outsiderCannotReadMessagesAfter() {
        assertThatThrownBy(() -> service.getMessagesAfter(99L, CONVERSATION_ID, 0L, 30))
                .isInstanceOfSatisfying(AppException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(403));
    }

    @Test
    void recallClearsContentAndNotifiesBothSides() {
        Message message = message(6L);
        message.setCreatedAt(LocalDateTime.now().minusHours(1));
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message));

        MessageResponse response = service.recallMessage(ME, 6L);

        assertThat(response.getRecalled()).isTrue();
        assertThat(response.getContent()).isNull();
        assertThat(message.getContent()).isNull();
        ArgumentCaptor<MessageRecalledEvent> event = ArgumentCaptor.forClass(MessageRecalledEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        assertThat(event.getValue().recipientId()).isEqualTo(OTHER);
    }

    @Test
    void cannotRecallSomeoneElsesMessage() {
        Message message = message(6L);
        message.setSender(other);
        message.setCreatedAt(LocalDateTime.now());
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message));

        assertThatThrownBy(() -> service.recallMessage(ME, 6L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        assertThat(message.getRecalledAt()).isNull();
    }

    @Test
    void cannotRecallAfterTheWindow() {
        Message message = message(6L);
        message.setCreatedAt(LocalDateTime.now().minusHours(25));
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message));

        assertThatThrownBy(() -> service.recallMessage(ME, 6L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void recallTwiceDoesNotPublishAgain() {
        Message message = message(6L);
        message.setCreatedAt(LocalDateTime.now().minusDays(3));
        message.setRecalledAt(LocalDateTime.now().minusDays(2));
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message));

        assertThat(service.recallMessage(ME, 6L).getRecalled()).isTrue();

        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void recalledMessageCannotBeTranslated() {
        Message message = message(6L);
        message.setContent(null);
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message));

        assertThatThrownBy(() -> service.getTranslatableContent(ME, 6L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void outsiderCannotTranslateMessage() {
        when(messageRepository.findById(6L)).thenReturn(Optional.of(message(6L)));

        assertThatThrownBy(() -> service.getTranslatableContent(99L, 6L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
    }

    @Test
    void blockedPairCannotMessage() {
        when(userBlockRepository.existsBetween(ME, OTHER)).thenReturn(true);

        assertThatThrownBy(() -> service.sendMessage(ME, textRequest()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void lockedSenderCannotMessage() {
        me.setIsActive(false);

        assertThatThrownBy(() -> service.sendMessage(ME, textRequest()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void blockedConversationCannotMessageAndShowsWhoBlocked() {
        UserBlock block = UserBlock.builder().id(new UserBlockId(ME, OTHER)).build();
        when(userBlockRepository.findBetween(eq(ME), any())).thenReturn(List.of(block));
        when(followService.findMutualIdsAmong(eq(ME), any())).thenReturn(Set.of(OTHER));

        ConversationResponse mine = service.getConversation(ME, CONVERSATION_ID);

        assertThat(mine.getCanMessage()).isFalse();
        assertThat(mine.getBlockedByMe()).isTrue();
    }

    @Test
    void personWhoWasBlockedDoesNotSeeTheBlockFlag() {
        UserBlock block = UserBlock.builder().id(new UserBlockId(OTHER, ME)).build();
        when(userBlockRepository.findBetween(eq(ME), any())).thenReturn(List.of(block));
        when(followService.findMutualIdsAmong(eq(ME), any())).thenReturn(Set.of(OTHER));

        ConversationResponse mine = service.getConversation(ME, CONVERSATION_ID);

        assertThat(mine.getCanMessage()).isFalse();
        assertThat(mine.getBlockedByMe()).isFalse();
    }

    @Test
    void contactsExcludeBlockedPeople() {
        User third = User.builder().id(3L).build();
        when(followService.getMutualFollows(ME)).thenReturn(List.of(other, third));
        when(userBlockRepository.findRelatedUserIds(ME)).thenReturn(List.of(OTHER));

        List<ChatUserResponse> contacts = service.getContacts(ME);

        assertThat(contacts).extracting(ChatUserResponse::getId).containsExactly(3L);
    }

    @Test
    void typingIsNotRelayedWhenBlocked() {
        when(userBlockRepository.existsBetween(ME, OTHER)).thenReturn(true);

        assertThat(service.findTypingRecipientId(ME, CONVERSATION_ID)).isNull();
    }

    @Test
    void imageMustBeOnOurCloudinary() {
        SendMessageRequest request = imageRequest("https://evil.example.com/tracker.png");

        assertThatThrownBy(() -> service.sendMessage(ME, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void imageMessageKeepsItsUrl() {
        String url = "https://res.cloudinary.com/demo/image/upload/v1/jlsp/chat/a.jpg";
        when(participantRepository.updateLastReadMessageId(CONVERSATION_ID, ME, 100L)).thenReturn(1);
        when(userRepository.getReferenceById(ME)).thenReturn(me);

        MessageResponse response = service.sendMessage(ME, imageRequest(url));

        assertThat(response.getType()).isEqualTo(MessageType.IMAGE);
        assertThat(response.getImageUrl()).isEqualTo(url);
    }

    @Test
    void replyKeepsAShortPreviewOfTheOriginal() {
        Message original = message(6L);
        original.setContent("あ".repeat(500));
        when(messageRepository.findById(6L)).thenReturn(Optional.of(original));
        when(participantRepository.updateLastReadMessageId(CONVERSATION_ID, ME, 100L)).thenReturn(1);
        when(userRepository.getReferenceById(ME)).thenReturn(me);
        SendMessageRequest request = textRequest();
        request.setReplyToId(6L);

        MessageResponse response = service.sendMessage(ME, request);

        assertThat(response.getReplyTo().getId()).isEqualTo(6L);
        assertThat(response.getReplyTo().getSenderId()).isEqualTo(ME);
        assertThat(response.getReplyTo().getContent()).hasSize(120);
    }

    @Test
    void cannotReplyToAMessageFromAnotherConversation() {
        Message elsewhere = message(6L);
        elsewhere.setConversation(Conversation.builder().id(99L).build());
        when(messageRepository.findById(6L)).thenReturn(Optional.of(elsewhere));
        SendMessageRequest request = textRequest();
        request.setReplyToId(6L);

        assertThatThrownBy(() -> service.sendMessage(ME, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void cannotReplyToARecalledMessage() {
        Message recalled = message(6L);
        recalled.setRecalledAt(LocalDateTime.now());
        when(messageRepository.findById(6L)).thenReturn(Optional.of(recalled));
        SendMessageRequest request = textRequest();
        request.setReplyToId(6L);

        assertThatThrownBy(() -> service.sendMessage(ME, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void replyPreviewShowsWhenTheOriginalWasRecalled() {
        Message original = message(6L);
        original.setContent(null);
        original.setRecalledAt(LocalDateTime.now());
        Message reply = message(7L);
        reply.setReplyTo(original);

        MessageResponse response = new ChatMapper().toMessageResponse(reply, java.util.Map.of());

        assertThat(response.getReplyTo().getRecalled()).isTrue();
        assertThat(response.getReplyTo().getContent()).isNull();
    }

    @Test
    void recallingAReplyDropsItsQuote() {
        Message reply = message(7L);
        reply.setReplyTo(message(6L));
        reply.setCreatedAt(LocalDateTime.now());
        when(messageRepository.findById(7L)).thenReturn(Optional.of(reply));

        assertThat(service.recallMessage(ME, 7L).getReplyTo()).isNull();
    }

    @Test
    void clearingHidesCurrentMessagesWithoutMarkingThemRead() {
        ConversationParticipant mine = participant(null);
        mine.setLastReadMessageId(3L);
        when(participantRepository.findById(mineId())).thenReturn(Optional.of(mine));
        when(messageRepository.findLatestId(CONVERSATION_ID)).thenReturn(9L);

        service.clearConversation(ME, CONVERSATION_ID);

        assertThat(mine.getClearedMessageId()).isEqualTo(9L);
        assertThat(mine.getLastReadMessageId()).isEqualTo(3L);
        verify(eventPublisher).publishEvent(new ConversationClearedEvent(CONVERSATION_ID, ME));
    }

    @Test
    void clearingAnEmptyConversationDoesNothing() {
        when(messageRepository.findLatestId(CONVERSATION_ID)).thenReturn(null);

        service.clearConversation(ME, CONVERSATION_ID);

        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void outsiderCannotClearConversation() {
        assertThatThrownBy(() -> service.clearConversation(99L, CONVERSATION_ID))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
    }

    @Test
    void historyStartsAfterTheClearedMark() {
        when(participantRepository.findById(mineId())).thenReturn(Optional.of(participant(9L)));
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(9L), any(Pageable.class))).thenReturn(List.of(message(10L)));

        MessagePageResponse page = service.getMessages(ME, CONVERSATION_ID, null, 30);

        assertThat(page.getContent()).extracting(m -> m.getId()).containsExactly(10L);
    }

    @Test
    void olderPagesStopAtTheClearedMark() {
        when(participantRepository.findById(mineId())).thenReturn(Optional.of(participant(9L)));
        when(messageRepository.findByConversationIdAndIdGreaterThanAndIdLessThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(9L), eq(12L), any(Pageable.class))).thenReturn(List.of());

        assertThat(service.getMessages(ME, CONVERSATION_ID, 12L, 30).getContent()).isEmpty();
    }

    @Test
    void missedMessagesNeverGoBelowTheClearedMark() {
        when(participantRepository.findById(mineId())).thenReturn(Optional.of(participant(9L)));
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(9L), any(Pageable.class))).thenReturn(List.of());

        assertThat(service.getMessagesAfter(ME, CONVERSATION_ID, 2L, 30).getContent()).isEmpty();
    }

    @Test
    void clearedConversationHidesItsLastMessage() {
        conversation.setLastMessage(message(9L));
        when(participantRepository.findByIdConversationIdIn(any())).thenReturn(List.of(participant(9L)));

        assertThat(service.getConversation(ME, CONVERSATION_ID).getLastMessage()).isNull();
    }

    @Test
    void newMessageAfterClearingIsShown() {
        conversation.setLastMessage(message(10L));
        when(participantRepository.findByIdConversationIdIn(any())).thenReturn(List.of(participant(9L)));

        assertThat(service.getConversation(ME, CONVERSATION_ID).getLastMessage().getId()).isEqualTo(10L);
    }

    @Test
    void otherPersonsClearedMarkDoesNotAffectMe() {
        conversation.setLastMessage(message(9L));
        ConversationParticipant theirs = ConversationParticipant.builder()
                .id(new ConversationParticipantId(CONVERSATION_ID, OTHER)).clearedMessageId(9L).build();
        when(participantRepository.findByIdConversationIdIn(any())).thenReturn(List.of(theirs));

        assertThat(service.getConversation(ME, CONVERSATION_ID).getLastMessage().getId()).isEqualTo(9L);
    }

    @Test
    void registeringAKnownTokenMovesItToTheCurrentUser() {
        DeviceToken device = DeviceToken.builder().token("abc").user(other).platform("android").build();
        when(deviceTokenRepository.findByToken("abc")).thenReturn(Optional.of(device));
        when(userRepository.getReferenceById(ME)).thenReturn(me);

        service.registerDevice(ME, "abc", "ios");

        assertThat(device.getUser()).isSameAs(me);
        assertThat(device.getPlatform()).isEqualTo("ios");
        verify(deviceTokenRepository).save(device);
    }

    private static ConversationParticipantId mineId() {
        return new ConversationParticipantId(CONVERSATION_ID, ME);
    }

    private static ConversationParticipant participant(Long clearedMessageId) {
        return ConversationParticipant.builder().id(mineId()).clearedMessageId(clearedMessageId).build();
    }

    @Test
    void sharingToSeveralPeopleNotifiesVideoOwnerOnce() {
        User third = User.builder().id(3L).isActive(true).build();
        User owner = User.builder().id(4L).isActive(true).build();
        when(userRepository.findById(3L)).thenReturn(Optional.of(third));
        when(followService.isMutual(ME, 3L)).thenReturn(true);
        when(conversationRepository.findByUserLowIdAndUserHighId(any(), any())).thenReturn(Optional.of(conversation));
        when(participantRepository.updateLastReadMessageId(any(), any(), any())).thenReturn(1);
        when(userRepository.getReferenceById(ME)).thenReturn(me);
        when(videoRepository.findById(7L)).thenReturn(Optional.of(approvedVideoOf(owner)));

        service.shareVideo(ME, 7L, new ShareVideoRequest(List.of(OTHER, 3L), null, null));

        assertThat(notificationEvents()).singleElement().satisfies(event -> {
            assertThat(event.recipientId()).isEqualTo(4L);
            assertThat(event.actorId()).isEqualTo(ME);
            assertThat(event.type()).isEqualTo(NotificationType.VIDEO_SHARED);
            assertThat(event.videoId()).isEqualTo(7L);
        });
    }

    @Test
    void sharingOnlyToTheVideoOwnerDoesNotNotifyThem() {
        when(conversationRepository.findByUserLowIdAndUserHighId(any(), any())).thenReturn(Optional.of(conversation));
        when(participantRepository.updateLastReadMessageId(any(), any(), any())).thenReturn(1);
        when(userRepository.getReferenceById(ME)).thenReturn(me);
        when(videoRepository.findById(7L)).thenReturn(Optional.of(approvedVideoOf(other)));

        service.shareVideo(ME, 7L, new ShareVideoRequest(List.of(OTHER), null, null));

        assertThat(notificationEvents()).isEmpty();
    }

    private List<NotificationRequestedEvent> notificationEvents() {
        ArgumentCaptor<Object> published = ArgumentCaptor.forClass(Object.class);
        verify(eventPublisher, org.mockito.Mockito.atLeast(0)).publishEvent(published.capture());
        return published.getAllValues().stream()
                .filter(NotificationRequestedEvent.class::isInstance)
                .map(NotificationRequestedEvent.class::cast)
                .toList();
    }

    private static Video approvedVideoOf(User owner) {
        return Video.builder().id(7L).user(owner).status(VideoStatus.PUBLIC).modStatus(VideoModStatus.APPROVED).build();
    }

    private SendMessageRequest textRequest() {
        return SendMessageRequest.builder()
                .conversationId(CONVERSATION_ID)
                .type(MessageType.TEXT)
                .content("xin chào")
                .build();
    }

    private SendMessageRequest imageRequest(String imageUrl) {
        return SendMessageRequest.builder()
                .conversationId(CONVERSATION_ID)
                .type(MessageType.IMAGE)
                .imageUrl(imageUrl)
                .build();
    }

    private Message message(long id) {
        return Message.builder()
                .id(id)
                .conversation(conversation)
                .sender(me)
                .type(MessageType.TEXT)
                .content("tin " + id)
                .clientMsgId("c" + id)
                .build();
    }
}
