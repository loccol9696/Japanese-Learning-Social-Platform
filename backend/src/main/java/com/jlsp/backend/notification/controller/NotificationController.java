package com.jlsp.backend.notification.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.NotificationCategory;
import com.jlsp.backend.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * API thông báo (tương tác và hệ thống). Thông báo mới đến realtime qua Socket.IO
 * ({@code notification:new}); các API này dùng để tải danh sách và đánh dấu đã đọc.
 */
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    /** GET /api/v1/notifications?category=INTERACTION|SYSTEM — mới nhất trước. */
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<NotificationResponse>>> list(
            @RequestParam(required = false) NotificationCategory category,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                notificationService.list(CurrentUser.requireId(), category, pageable)));
    }

    /** GET /api/v1/notifications/unread-count — số thông báo chưa đọc (badge chuông). */
    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> unreadCount() {
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("count", notificationService.unreadCount(CurrentUser.requireId()))));
    }

    /** POST /api/v1/notifications/{id}/read — đánh dấu một thông báo đã đọc. */
    @PostMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable Long id) {
        notificationService.markRead(CurrentUser.requireId(), id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã đánh dấu đã đọc", null));
    }

    /** POST /api/v1/notifications/read-all — đánh dấu tất cả đã đọc. */
    @PostMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllRead() {
        notificationService.markAllRead(CurrentUser.requireId());
        return ResponseEntity.ok(ApiResponse.success(200, "Đã đánh dấu tất cả đã đọc", null));
    }
}
