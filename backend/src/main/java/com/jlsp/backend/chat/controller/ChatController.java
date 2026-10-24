package com.jlsp.backend.chat.controller;

import com.jlsp.backend.chat.dto.request.CreateConversationRequest;
import com.jlsp.backend.chat.dto.request.MarkReadRequest;
import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareVideoRequest;
import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.ReadReceiptResponse;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * API chat 1-1. Gửi/nhận realtime đi qua Socket.IO; các API này dùng để tải
 * dữ liệu ban đầu và làm đường gửi dự phòng khi socket mất kết nối.
 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    /** GET /api/v1/chat/contacts — những người follow lẫn nhau (được phép nhắn tin). */
    @GetMapping("/chat/contacts")
    public ResponseEntity<ApiResponse<List<ChatUserResponse>>> getContacts() {
        return ResponseEntity.ok(ApiResponse.success(chatService.getContacts(CurrentUser.requireId())));
    }

    /** GET /api/v1/chat/conversations — danh sách hội thoại, mới nhất trước. */
    @GetMapping("/chat/conversations")
    public ResponseEntity<ApiResponse<PageResponse<ConversationResponse>>> getConversations(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.getConversations(CurrentUser.requireId(), pageable)));
    }

    /** POST /api/v1/chat/conversations — mở (hoặc tạo) hội thoại với một người. */
    @PostMapping("/chat/conversations")
    public ResponseEntity<ApiResponse<ConversationResponse>> openConversation(
            @Valid @RequestBody CreateConversationRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.getOrCreateConversation(CurrentUser.requireId(), request.getRecipientId())));
    }

    @GetMapping("/chat/conversations/{id}")
    public ResponseEntity<ApiResponse<ConversationResponse>> getConversation(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(chatService.getConversation(CurrentUser.requireId(), id)));
    }

    /** GET /api/v1/chat/conversations/{id}/messages?before={messageId}&size=30 */
    @GetMapping("/chat/conversations/{id}/messages")
    public ResponseEntity<ApiResponse<MessagePageResponse>> getMessages(
            @PathVariable Long id,
            @RequestParam(required = false) Long before,
            @RequestParam(defaultValue = "30") int size) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.getMessages(CurrentUser.requireId(), id, before, size)));
    }

    /** POST /api/v1/chat/conversations/{id}/messages — gửi tin (dự phòng khi socket rớt). */
    @PostMapping("/chat/conversations/{id}/messages")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @PathVariable Long id,
            @Valid @RequestBody SendMessageRequest request) {
        request.setConversationId(id);
        request.setRecipientId(null);
        MessageResponse response = chatService.sendMessage(CurrentUser.requireId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Đã gửi", response));
    }

    @PostMapping("/chat/conversations/{id}/read")
    public ResponseEntity<ApiResponse<ReadReceiptResponse>> markAsRead(
            @PathVariable Long id,
            @Valid @RequestBody MarkReadRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                chatService.markAsRead(CurrentUser.requireId(), id, request.getLastMessageId())));
    }

    /** GET /api/v1/chat/unread-count — tổng số tin chưa đọc (badge Inbox). */
    @GetMapping("/chat/unread-count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getUnreadCount() {
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("count", chatService.getUnreadCount(CurrentUser.requireId()))));
    }

    /** POST /api/v1/videos/{id}/share — chia sẻ video cho nhiều người (follow lẫn nhau). */
    @PostMapping("/videos/{id}/share")
    public ResponseEntity<ApiResponse<List<MessageResponse>>> shareVideo(
            @PathVariable Long id,
            @Valid @RequestBody ShareVideoRequest request) {
        List<MessageResponse> sent = chatService.shareVideo(CurrentUser.requireId(), id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã chia sẻ cho " + sent.size() + " người", sent));
    }
}
