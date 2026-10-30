package com.jlsp.backend.notification.dto.response;

import com.jlsp.backend.notification.entity.NotificationCategory;
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
    private NotificationCategory category;

    /** Người thực hiện; null với thông báo hệ thống. */
    private Long actorId;
    private String actorName;
    private String actorAvatarUrl;

    private Long videoId;
    private String videoTitle;
    private String videoThumbnailUrl;
    /** false khi video đã bị xoá. */
    private boolean videoAvailable;

    private Long commentId;
    /** Đoạn bình luận (VIDEO_COMMENTED) hoặc lý do từ chối (VIDEO_REJECTED). */
    private String detail;

    private boolean read;
    private LocalDateTime createdAt;
}
