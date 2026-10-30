package com.jlsp.backend.notification.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.NotificationCategory;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import org.springframework.data.domain.Pageable;

import java.util.Collection;

public interface NotificationService {

    /**
     * Lưu thông báo từ một yêu cầu nghiệp vụ. Bỏ qua khi người nhận tự tương tác với nội dung
     * của mình, khi hai bên chặn nhau hoặc khi khoá chống trùng đã tồn tại.
     */
    void record(NotificationRequestedEvent event);

    /** Danh sách thông báo của người dùng, mới nhất trước; category null thì lấy tất cả. */
    PageResponse<NotificationResponse> list(Long userId, NotificationCategory category, Pageable pageable);

    long unreadCount(Long userId);

    void markRead(Long userId, Long notificationId);

    void markAllRead(Long userId);

    /** Xoá thông báo của các bình luận đã bị xoá để nội dung đã xoá không còn trong danh sách. */
    void deleteByComments(Collection<Long> commentIds);
}
