package com.jlsp.backend.chat.service.impl;

import com.jlsp.backend.chat.dto.request.ShareDeckRequest;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.entity.Conversation;
import com.jlsp.backend.chat.entity.ConversationParticipant;
import com.jlsp.backend.chat.entity.ConversationParticipantId;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.mapper.ChatMapper;
import com.jlsp.backend.chat.repository.ConversationParticipantRepository;
import com.jlsp.backend.chat.repository.ConversationRepository;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.service.ChatRateLimiter;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.flashcard.entity.FlashcardSet;
import com.jlsp.backend.flashcard.repository.FlashcardRepository;
import com.jlsp.backend.flashcard.repository.FlashcardSetRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.FollowService;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

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

    private MessageRepository messageRepository;
    private ConversationRepository conversationRepository;
    private ConversationParticipantRepository participantRepository;
    private UserRepository userRepository;
    private FollowService followService;
    private FlashcardSetRepository flashcardSetRepository;
    private FlashcardRepository flashcardRepository;
    private ChatServiceImpl service;
    private Conversation conversation;
    private User me;

    @BeforeEach
    void setUp() {
        conversationRepository = mock(ConversationRepository.class);
        messageRepository = mock(MessageRepository.class);
        participantRepository = mock(ConversationParticipantRepository.class);
        userRepository = mock(UserRepository.class);
        followService = mock(FollowService.class);
        flashcardSetRepository = mock(FlashcardSetRepository.class);
        flashcardRepository = mock(FlashcardRepository.class);
        service = new ChatServiceImpl(
                conversationRepository,
                participantRepository,
                messageRepository,
                userRepository,
                mock(VideoRepository.class),
                followService,
                new ChatMapper(),
                new ChatRateLimiter(),
                mock(ApplicationEventPublisher.class),
                flashcardSetRepository,
                flashcardRepository);

        me = User.builder().id(ME).build();
        User other = User.builder().id(2L).build();
        conversation = Conversation.builder().id(CONVERSATION_ID).userLow(me).userHigh(other).build();
        when(conversationRepository.findDetailById(CONVERSATION_ID)).thenReturn(Optional.of(conversation));
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

    // ---- xoá cuộc trò chuyện phía người dùng

    private ConversationParticipant participant(Long lastRead, Long clearedBefore) {
        return ConversationParticipant.builder()
                .id(new ConversationParticipantId(CONVERSATION_ID, ME))
                .lastReadMessageId(lastRead)
                .clearedBeforeMessageId(clearedBefore)
                .build();
    }

    private void givenParticipant(ConversationParticipant participant) {
        when(participantRepository.findById(new ConversationParticipantId(CONVERSATION_ID, ME)))
                .thenReturn(Optional.of(participant));
    }

    @Test
    void clearingRecordsTheLatestMessageAsCutoffAndMarksItRead() {
        ConversationParticipant mine = participant(3L, null);
        givenParticipant(mine);
        when(messageRepository.findLatestId(CONVERSATION_ID)).thenReturn(15L);

        service.clearConversation(ME, CONVERSATION_ID);

        assertThat(mine.getClearedBeforeMessageId()).isEqualTo(15L);
        assertThat(mine.getLastReadMessageId()).isEqualTo(15L);
        verify(participantRepository).save(mine);
    }

    @Test
    void clearingNeverMovesTheReadMarkerBackwards() {
        ConversationParticipant mine = participant(20L, null);
        givenParticipant(mine);
        when(messageRepository.findLatestId(CONVERSATION_ID)).thenReturn(15L);

        service.clearConversation(ME, CONVERSATION_ID);

        assertThat(mine.getLastReadMessageId()).isEqualTo(20L);
    }

    @Test
    void clearingAnEmptyConversationDoesNothing() {
        when(messageRepository.findLatestId(CONVERSATION_ID)).thenReturn(null);

        service.clearConversation(ME, CONVERSATION_ID);

        verify(participantRepository, never()).save(any());
    }

    @Test
    void outsiderCannotClearSomeoneElsesConversation() {
        assertThatThrownBy(() -> service.clearConversation(99L, CONVERSATION_ID))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(participantRepository, never()).save(any());
    }

    @Test
    void firstPageSkipsMessagesTheViewerCleared() {
        givenParticipant(participant(null, 15L));
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(15L), any(Pageable.class)))
                .thenReturn(List.of(message(17L), message(16L)));

        MessagePageResponse page = service.getMessages(ME, CONVERSATION_ID, null, 30);

        assertThat(page.getContent()).extracting(m -> m.getId()).containsExactly(17L, 16L);
    }

    @Test
    void firstPageWithoutAnyClearingStartsFromTheBeginning() {
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(0L), any(Pageable.class)))
                .thenReturn(List.of(message(2L), message(1L)));

        assertThat(service.getMessages(ME, CONVERSATION_ID, null, 30).getContent()).hasSize(2);
    }

    @Test
    void olderPagesAlsoStopAtTheCutoff() {
        givenParticipant(participant(null, 15L));
        when(messageRepository.findByConversationIdAndIdLessThanAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(20L), eq(15L), any(Pageable.class)))
                .thenReturn(List.of(message(19L)));

        MessagePageResponse page = service.getMessages(ME, CONVERSATION_ID, 20L, 30);

        assertThat(page.getContent()).extracting(m -> m.getId()).containsExactly(19L);
        assertThat(page.getHasMore()).isFalse();
    }

    @Test
    void syncAfterAnOldCursorStillNeverReturnsClearedMessages() {
        givenParticipant(participant(null, 15L));
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(15L), any(Pageable.class)))
                .thenReturn(List.of(message(16L)));

        service.getMessagesAfter(ME, CONVERSATION_ID, 5L, 30);

        verify(messageRepository).findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(15L), any(Pageable.class));
    }

    @Test
    void syncAfterANewerCursorKeepsTheCursor() {
        givenParticipant(participant(null, 15L));
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(20L), any(Pageable.class)))
                .thenReturn(List.of());

        service.getMessagesAfter(ME, CONVERSATION_ID, 20L, 30);

        verify(messageRepository).findByConversationIdAndIdGreaterThanOrderByIdAsc(
                eq(CONVERSATION_ID), eq(20L), any(Pageable.class));
    }

    @Test
    void reopeningAClearedConversationShowsNoLastMessage() {
        conversation.setLastMessage(message(15L));
        when(participantRepository.findByIdConversationIdIn(any()))
                .thenReturn(List.of(participant(15L, 15L)));

        ConversationResponse response = service.getConversation(ME, CONVERSATION_ID);

        assertThat(response.getLastMessage()).isNull();
        assertThat(response.getUnreadCount()).isZero();
    }

    @Test
    void aMessageNewerThanTheCutoffIsShownAgain() {
        conversation.setLastMessage(message(16L));
        when(participantRepository.findByIdConversationIdIn(any()))
                .thenReturn(List.of(participant(15L, 15L)));

        ConversationResponse response = service.getConversation(ME, CONVERSATION_ID);

        assertThat(response.getLastMessage()).isNotNull();
        assertThat(response.getLastMessage().getId()).isEqualTo(16L);
    }

    // ---- chia sẻ bộ thẻ

    private static final long DECK_ID = 5L;
    private static final long FRIEND_ID = 2L;

    private FlashcardSet deck(boolean isPublic) {
        return FlashcardSet.builder().setId(DECK_ID).title("N2 xàm xàm").isPublic(isPublic).build();
    }

    private static IdCount count(long id, long total) {
        return new IdCount() {
            @Override
            public Long getId() {
                return id;
            }

            @Override
            public Long getTotal() {
                return total;
            }
        };
    }

    /** Dựng đủ phần phụ thuộc để gửi được một tin nhắn tới bạn bè đang follow lẫn nhau. */
    private void givenMutualFriendAndWritableChat() {
        User friend = User.builder().id(FRIEND_ID).isActive(true).build();
        when(userRepository.findById(FRIEND_ID)).thenReturn(Optional.of(friend));
        when(userRepository.getReferenceById(ME)).thenReturn(me);
        when(followService.isMutual(ME, FRIEND_ID)).thenReturn(true);
        when(conversationRepository.findByUserLowIdAndUserHighId(ME, FRIEND_ID)).thenReturn(Optional.of(conversation));
        when(conversationRepository.save(any(Conversation.class))).thenAnswer(inv -> inv.getArgument(0));
        when(participantRepository.updateLastReadMessageId(any(), any(), any())).thenReturn(1);
        when(messageRepository.save(any(Message.class))).thenAnswer(inv -> {
            Message m = inv.getArgument(0);
            m.setId(100L);
            m.setCreatedAt(LocalDateTime.now());
            return m;
        });
    }

    private static ShareDeckRequest shareTo(Long... recipients) {
        return new ShareDeckRequest(List.of(recipients), "Học bộ này nhé");
    }

    @Test
    void sharingAPublicDeckSendsADeckShareMessageWithTitleAndCardCount() {
        givenMutualFriendAndWritableChat();
        when(flashcardSetRepository.findById(DECK_ID)).thenReturn(Optional.of(deck(true)));
        when(flashcardRepository.countBySetIds(any())).thenReturn(List.of(count(DECK_ID, 12)));

        List<MessageResponse> sent = service.shareDeck(ME, DECK_ID, shareTo(FRIEND_ID));

        assertThat(sent).hasSize(1);
        MessageResponse message = sent.get(0);
        assertThat(message.getType()).isEqualTo(MessageType.DECK_SHARE);
        assertThat(message.getContent()).isEqualTo("Học bộ này nhé");
        assertThat(message.getDeck().getAvailable()).isTrue();
        assertThat(message.getDeck().getTitle()).isEqualTo("N2 xàm xàm");
        assertThat(message.getDeck().getCardCount()).isEqualTo(12);
        assertThat(message.getVideo()).isNull();

        ArgumentCaptor<Message> saved = ArgumentCaptor.forClass(Message.class);
        verify(messageRepository).save(saved.capture());
        assertThat(saved.getValue().getDeckId()).isEqualTo(DECK_ID);
    }

    @Test
    void aPrivateDeckCannotBeSharedAndNothingIsSent() {
        givenMutualFriendAndWritableChat();
        when(flashcardSetRepository.findById(DECK_ID)).thenReturn(Optional.of(deck(false)));

        assertThatThrownBy(() -> service.shareDeck(ME, DECK_ID, shareTo(FRIEND_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void sharingAMissingDeckIsNotFound() {
        when(flashcardSetRepository.findById(DECK_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.shareDeck(ME, DECK_ID, shareTo(FRIEND_ID)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(messageRepository, never()).save(any());
    }

    @Test
    void recipientsMustFollowEachOtherAndNothingIsSentToAnyoneIfOneFails() {
        givenMutualFriendAndWritableChat();
        User stranger = User.builder().id(3L).isActive(true).build();
        when(userRepository.findById(3L)).thenReturn(Optional.of(stranger));
        when(followService.isMutual(ME, 3L)).thenReturn(false);
        when(flashcardSetRepository.findById(DECK_ID)).thenReturn(Optional.of(deck(true)));

        assertThatThrownBy(() -> service.shareDeck(ME, DECK_ID, shareTo(FRIEND_ID, 3L)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void historyShowsDeckSharesAndMarksDeletedOrPrivateDecksUnavailable() {
        Message shared = message(30L);
        shared.setType(MessageType.DECK_SHARE);
        shared.setDeckId(DECK_ID);
        Message gone = message(31L);
        gone.setType(MessageType.DECK_SHARE);
        gone.setDeckId(77L);
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(0L), any(Pageable.class))).thenReturn(List.of(gone, shared));
        when(flashcardSetRepository.findAllById(any())).thenReturn(List.of(deck(true)));
        when(flashcardRepository.countBySetIds(any())).thenReturn(List.of(count(DECK_ID, 8)));

        MessagePageResponse page = service.getMessages(ME, CONVERSATION_ID, null, 30);

        assertThat(page.getContent().get(1).getDeck().getTitle()).isEqualTo("N2 xàm xàm");
        assertThat(page.getContent().get(1).getDeck().getCardCount()).isEqualTo(8);
        assertThat(page.getContent().get(0).getDeck().getAvailable()).isFalse();
        assertThat(page.getContent().get(0).getDeck().getTitle()).isNull();
    }

    @Test
    void deckSetsAreLoadedWithOneQueryNotOnePerMessage() {
        Message a = message(40L);
        a.setType(MessageType.DECK_SHARE);
        a.setDeckId(DECK_ID);
        Message b = message(41L);
        b.setType(MessageType.DECK_SHARE);
        b.setDeckId(DECK_ID);
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdDesc(
                eq(CONVERSATION_ID), eq(0L), any(Pageable.class))).thenReturn(List.of(b, a));
        when(flashcardSetRepository.findAllById(any())).thenReturn(List.of(deck(true)));
        when(flashcardRepository.countBySetIds(any())).thenReturn(List.of(count(DECK_ID, 3)));

        service.getMessages(ME, CONVERSATION_ID, null, 30);

        verify(flashcardSetRepository).findAllById(any());
        verify(flashcardRepository).countBySetIds(any());
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
