package com.jlsp.backend.notification.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.NotificationResponse;
import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
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
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class NotificationServiceImpl implements NotificationService {

    private static final int MESSAGE_MAX = 500;

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional
    public void notify(Long recipientId, Long actorId, NotificationType type,
                       Long videoId, Long commentId, String message) {
        try {
            if (recipientId == null || recipientId.equals(actorId)) {
                return;
            }
            if (isDuplicate(recipientId, actorId, type, videoId)) {
                return;
            }

            User actor = actorId == null ? null : userRepository.findById(actorId).orElse(null);
            Notification saved = notificationRepository.save(Notification.builder()
                    .recipient(userRepository.getReferenceById(recipientId))
                    .actor(actor)
                    .type(type)
                    .videoId(videoId)
                    .commentId(commentId)
                    .message(truncate(message))
                    .build());

            String videoTitle = videoId == null ? null
                    : videoRepository.findById(videoId).map(Video::getTitle).orElse(null);
            eventPublisher.publishEvent(new NotificationCreatedEvent(
                    recipientId,
                    toResponse(saved, videoTitle),
                    notificationRepository.countByRecipientIdAndIsReadFalse(recipientId)));
        } catch (RuntimeException e) {
            // Thông báo chỉ là phụ trợ: tuyệt đối không làm hỏng thao tác gốc.
            log.warn("Không tạo được thông báo {} cho user {}: {}", type, recipientId, e.toString());
        }
    }

    private boolean isDuplicate(Long recipientId, Long actorId, NotificationType type, Long videoId) {
        if (actorId == null) {
            return false;
        }
        return switch (type) {
            case LIKE -> notificationRepository.existsByRecipientIdAndActorIdAndTypeAndVideoId(
                    recipientId, actorId, type, videoId);
            case FOLLOW -> notificationRepository.existsByRecipientIdAndActorIdAndType(
                    recipientId, actorId, type);
            default -> false;
        };
    }

    @Override
    public PageResponse<NotificationResponse> list(Long userId, boolean unreadOnly, Pageable pageable) {
        Page<Notification> page = unreadOnly
                ? notificationRepository.findByRecipientIdAndIsReadFalse(userId, pageable)
                : notificationRepository.findByRecipientId(userId, pageable);

        // Một truy vấn gộp cho tiêu đề video của cả trang.
        Set<Long> videoIds = page.getContent().stream()
                .map(Notification::getVideoId).filter(id -> id != null).collect(Collectors.toSet());
        Map<Long, String> titles = new HashMap<>();
        if (!videoIds.isEmpty()) {
            videoRepository.findAllById(videoIds).forEach(v -> titles.put(v.getId(), v.getTitle()));
        }

        List<NotificationResponse> content = page.getContent().stream()
                .map(n -> toResponse(n, n.getVideoId() == null ? null : titles.get(n.getVideoId())))
                .toList();
        return PageResponse.<NotificationResponse>builder()
                .content(content)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    public long unreadCount(Long userId) {
        return notificationRepository.countByRecipientIdAndIsReadFalse(userId);
    }

    @Override
    @Transactional
    public void markRead(Long userId, Long notificationId) {
        Notification notification = notificationRepository.findByIdAndRecipientId(notificationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Notification", "id", notificationId));
        if (!Boolean.TRUE.equals(notification.getIsRead())) {
            notification.setIsRead(true);
            notificationRepository.save(notification);
        }
    }

    @Override
    @Transactional
    public int markAllRead(Long userId) {
        return notificationRepository.markAllRead(userId);
    }

    private static String truncate(String message) {
        if (message == null) return null;
        String trimmed = message.trim();
        if (trimmed.isEmpty()) return null;
        return trimmed.length() <= MESSAGE_MAX ? trimmed : trimmed.substring(0, MESSAGE_MAX - 1) + "…";
    }

    private static NotificationResponse toResponse(Notification n, String videoTitle) {
        User actor = n.getActor();
        return NotificationResponse.builder()
                .id(n.getId())
                .type(n.getType())
                .isRead(n.getIsRead())
                .createdAt(n.getCreatedAt())
                .actorId(actor == null ? null : actor.getId())
                .actorUsername(actor == null ? null : actor.getUsername())
                .actorDisplayName(actor == null ? null : actor.getDisplayName())
                .actorAvatarUrl(actor == null ? null : actor.getAvatarUrl())
                .videoId(n.getVideoId())
                .videoTitle(videoTitle)
                .commentId(n.getCommentId())
                .message(n.getMessage())
                .build();
    }
}
