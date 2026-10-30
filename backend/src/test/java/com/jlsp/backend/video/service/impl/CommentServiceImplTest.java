package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CommentServiceImplTest {

    private static final long OWNER = 1L;
    private static final long COMMENTER = 2L;
    private static final long VIDEO = 7L;

    private VideoCommentRepository commentRepository;
    private NotificationService notificationService;
    private ApplicationEventPublisher eventPublisher;
    private CommentServiceImpl service;
    private Video video;
    private User commenter;

    @BeforeEach
    void setUp() {
        commentRepository = mock(VideoCommentRepository.class);
        VideoRepository videoRepository = mock(VideoRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        notificationService = mock(NotificationService.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        service = new CommentServiceImpl(commentRepository, videoRepository, userRepository,
                notificationService, eventPublisher);

        video = Video.builder().id(VIDEO).user(User.builder().id(OWNER).build()).build();
        commenter = User.builder().id(COMMENTER).username("hana").build();
        when(videoRepository.findById(VIDEO)).thenReturn(Optional.of(video));
        when(userRepository.findById(COMMENTER)).thenReturn(Optional.of(commenter));
        when(commentRepository.save(any(VideoComment.class))).thenAnswer(call -> {
            VideoComment saved = call.getArgument(0);
            saved.setId(9L);
            return saved;
        });
    }

    @Test
    void commentNotifiesVideoOwnerWithTrimmedContent() {
        service.create(VIDEO, COMMENTER, request("  hay quá  ", null));

        ArgumentCaptor<NotificationRequestedEvent> event = ArgumentCaptor.forClass(NotificationRequestedEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        assertThat(event.getValue().type()).isEqualTo(NotificationType.VIDEO_COMMENTED);
        assertThat(event.getValue().recipientId()).isEqualTo(OWNER);
        assertThat(event.getValue().actorId()).isEqualTo(COMMENTER);
        assertThat(event.getValue().commentId()).isEqualTo(9L);
        assertThat(event.getValue().detail()).isEqualTo("hay quá");
    }

    @Test
    void deletingCommentAlsoRemovesNotificationsOfItsReplies() {
        VideoComment comment = VideoComment.builder().id(9L).video(video).user(commenter).content("hay").build();
        VideoComment reply = VideoComment.builder().id(10L).video(video).user(commenter).parent(comment)
                .content("cảm ơn").build();
        when(commentRepository.findById(9L)).thenReturn(Optional.of(comment));
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(9L)).thenReturn(List.of(reply));

        service.delete(VIDEO, 9L, COMMENTER, false);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<Long>> ids = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(notificationService).deleteByComments(ids.capture());
        assertThat(ids.getValue()).containsExactlyInAnyOrder(9L, 10L);
    }

    private static CreateCommentRequest request(String content, Long parentId) {
        CreateCommentRequest request = new CreateCommentRequest();
        request.setContent(content);
        request.setParentId(parentId);
        return request;
    }
}
