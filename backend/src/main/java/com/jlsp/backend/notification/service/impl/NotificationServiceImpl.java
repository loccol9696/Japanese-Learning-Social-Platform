package com.jlsp.backend.notification.service.impl;

import com.jlsp.backend.chat.repository.UserBlockRepository;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationCategory;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.notification.repository.NotificationRepository;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
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

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class NotificationServiceImpl implements NotificationService {

    static final int MAX_PAGE_SIZE = 50;
    static final int MAX_DETAIL_LENGTH = 200;

    private final NotificationRepository notificationRepository;
    private final UserBlockRepository userBlockRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional
    public void record(NotificationRequestedEvent event) {
        Long recipientId = event.recipientId();
        Long actorId = event.actorId();
        if (recipientId == null || recipientId.equals(actorId)) {
            return;
        }
        if (actorId != null && userBlockRepository.existsBetween(recipientId, actorId)) {
            return;
        }
        if (event.dedupeKey() != null
                && notificationRepository.existsByRecipientIdAndDedupeKey(recipientId, event.dedupeKey())) {
            return;
        }

        Notification saved = notificationRepository.save(Notification.builder()
                .recipientId(recipientId)
                .actorId(actorId)
                .type(event.type())
                .videoId(event.videoId())
                .commentId(event.commentId())
                .detail(shorten(event.detail()))
                .dedupeKey(event.dedupeKey())
                .build());

        NotificationResponse response = toResponses(List.of(saved)).get(0);
        eventPublisher.publishEvent(new NotificationCreatedEvent(response, recipientId));
    }

    @Override
    public PageResponse<NotificationResponse> list(Long userId, NotificationCategory category, Pageable pageable) {
        Pageable bounded = PageRequest.of(Math.max(pageable.getPageNumber(), 0),
                Math.min(Math.max(pageable.getPageSize(), 1), MAX_PAGE_SIZE));
        List<NotificationType> types = category == null
                ? List.of(NotificationType.values())
                : NotificationType.ofCategory(category);

        Page<Notification> page = notificationRepository
                .findByRecipientIdAndTypeInOrderByCreatedAtDescIdDesc(userId, types, bounded);
        return PageResponse.<NotificationResponse>builder()
                .content(toResponses(page.getContent()))
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    public long unreadCount(Long userId) {
        return notificationRepository.countByRecipientIdAndReadAtIsNull(userId);
    }

    @Override
    @Transactional
    public void markRead(Long userId, Long notificationId) {
        notificationRepository.markRead(notificationId, userId, LocalDateTime.now());
    }

    @Override
    @Transactional
    public void markAllRead(Long userId) {
        notificationRepository.markAllRead(userId, LocalDateTime.now());
    }

    @Override
    @Transactional
    public void deleteByComments(Collection<Long> commentIds) {
        if (!commentIds.isEmpty()) {
            notificationRepository.deleteByCommentIds(commentIds);
        }
    }

    private List<NotificationResponse> toResponses(List<Notification> notifications) {
        List<Long> actorIds = notifications.stream().map(Notification::getActorId)
                .filter(Objects::nonNull).distinct().toList();
        List<Long> videoIds = notifications.stream().map(Notification::getVideoId)
                .filter(Objects::nonNull).distinct().toList();
        Map<Long, User> actors = userRepository.findAllById(actorIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<Long, Video> videos = videoRepository.findAllById(videoIds).stream()
                .collect(Collectors.toMap(Video::getId, Function.identity()));

        return notifications.stream()
                .map(n -> toResponse(n, actors.get(n.getActorId()), videos.get(n.getVideoId())))
                .toList();
    }

    private static NotificationResponse toResponse(Notification n, User actor, Video video) {
        return NotificationResponse.builder()
                .id(n.getId())
                .type(n.getType())
                .category(n.getType().getCategory())
                .actorId(n.getActorId())
                .actorName(actor == null ? null : displayName(actor))
                .actorAvatarUrl(actor == null ? null : actor.getAvatarUrl())
                .videoId(n.getVideoId())
                .videoTitle(video == null ? null : video.getTitle())
                .videoThumbnailUrl(video == null ? null : video.getThumbnailUrl())
                .videoAvailable(video != null)
                .commentId(n.getCommentId())
                .detail(n.getDetail())
                .read(n.getReadAt() != null)
                .createdAt(n.getCreatedAt())
                .build();
    }

    static String displayName(User user) {
        String name = user.getDisplayName();
        return name == null || name.isBlank() ? user.getUsername() : name;
    }

    private static String shorten(String text) {
        if (text == null) {
            return null;
        }
        String trimmed = text.strip();
        return trimmed.length() <= MAX_DETAIL_LENGTH ? trimmed : trimmed.substring(0, MAX_DETAIL_LENGTH) + "…";
    }
}
