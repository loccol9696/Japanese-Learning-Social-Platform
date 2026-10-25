package com.jlsp.backend.chat.service.impl;

import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.entity.Conversation;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.mapper.ChatMapper;
import com.jlsp.backend.chat.repository.ConversationParticipantRepository;
import com.jlsp.backend.chat.repository.ConversationRepository;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.service.ChatRateLimiter;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.FollowService;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ChatServiceImplTest {

    private static final long CONVERSATION_ID = 10L;
    private static final long ME = 1L;

    private MessageRepository messageRepository;
    private ConversationRepository conversationRepository;
    private ChatServiceImpl service;
    private Conversation conversation;
    private User me;

    @BeforeEach
    void setUp() {
        conversationRepository = mock(ConversationRepository.class);
        messageRepository = mock(MessageRepository.class);
        service = new ChatServiceImpl(
                conversationRepository,
                mock(ConversationParticipantRepository.class),
                messageRepository,
                mock(UserRepository.class),
                mock(VideoRepository.class),
                mock(FollowService.class),
                new ChatMapper(),
                new ChatRateLimiter(),
                mock(ApplicationEventPublisher.class));

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
