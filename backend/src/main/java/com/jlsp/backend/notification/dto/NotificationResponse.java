package com.jlsp.backend.notification.dto;

import com.jlsp.backend.notification.entity.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationResponse {
    private Long id;
    private NotificationType type;
    private Boolean isRead;
    private LocalDateTime createdAt;

    /** Người gây ra sự kiện; null với thông báo từ hệ thống / kiểm duyệt. */
    private Long actorId;
    private String actorUsername;
    private String actorDisplayName;
    private String actorAvatarUrl;

    private Long videoId;
    private String videoTitle;
    private Long commentId;
    private String message;
}
