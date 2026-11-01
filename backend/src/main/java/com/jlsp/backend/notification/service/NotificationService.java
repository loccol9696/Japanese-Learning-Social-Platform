package com.jlsp.backend.notification.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.NotificationResponse;
import com.jlsp.backend.notification.entity.NotificationType;
import org.springframework.data.domain.Pageable;

public interface NotificationService {

    /**
     * Tạo thông báo cho {@code recipientId}. Không bao giờ ném lỗi ra ngoài để không làm hỏng
     * thao tác chính (thích, bình luận...). Bỏ qua khi người nhận chính là người gây ra sự kiện, và
     * chống trùng cho LIKE / FOLLOW.
     *
     * @param actorId null nếu thông báo do hệ thống / kiểm duyệt viên (ẩn danh)
     */
    void notify(Long recipientId, Long actorId, NotificationType type,
                Long videoId, Long commentId, String message);

    /** Thông báo về một báo cáo (ẩn danh người xử lý); {@code reportId} để người nhận mở xem kết quả. */
    void notifyReportResult(Long recipientId, NotificationType type, Long videoId, Long reportId, String message);

    /** Người này có nhận thông báo về báo cáo đó không; dùng để cho chủ nội dung xem kết quả. */
    boolean wasNotifiedAboutReport(Long recipientId, Long reportId);

    PageResponse<NotificationResponse> list(Long userId, boolean unreadOnly, Pageable pageable);

    long unreadCount(Long userId);

    void markRead(Long userId, Long notificationId);

    /** Đánh dấu tất cả đã đọc; trả về số thông báo đã đổi trạng thái. */
    int markAllRead(Long userId);
}
