package com.jlsp.backend.chat.controller;

import com.jlsp.backend.chat.dto.request.CreateConversationRequest;
import com.jlsp.backend.chat.dto.request.MarkReadRequest;
import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.ShareDeckRequest;
import com.jlsp.backend.chat.dto.request.ShareVideoRequest;
import com.jlsp.backend.chat.dto.response.ChatUserResponse;
import com.jlsp.backend.chat.dto.response.ConversationResponse;
import com.jlsp.backend.chat.dto.response.MessagePageResponse;
import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.dto.response.ReadReceiptResponse;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
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

    /** DELETE /api/v1/chat/conversations/{id} — xoá cuộc trò chuyện ở phía mình (người kia vẫn giữ lịch sử). */
    @DeleteMapping("/chat/conversations/{id}")
    public ResponseEntity<ApiResponse<Void>> clearConversation(@PathVariable Long id) {
        chatService.clearConversation(CurrentUser.requireId(), id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã xoá cuộc trò chuyện", null));
    }

    /**
     * GET /api/v1/chat/conversations/{id}/messages?before={messageId}&size=30 — lịch sử, mới nhất trước.
     * <br>GET .../messages?after={messageId}&size=30 — tin mới hơn mốc đó, cũ nhất trước
     * (đồng bộ phần đã lỡ sau khi mất kết nối). Không dùng chung before và after.
     */
    @GetMapping("/chat/conversations/{id}/messages")
    public ResponseEntity<ApiResponse<MessagePageResponse>> getMessages(
            @PathVariable Long id,
            @RequestParam(required = false) Long before,
            @RequestParam(required = false) Long after,
            @RequestParam(defaultValue = "30") int size) {
        if (before != null && after != null) {
            throw new AppException(400, "Chỉ dùng một trong hai tham số before hoặc after");
        }
        Long userId = CurrentUser.requireId();
        MessagePageResponse page = after != null
                ? chatService.getMessagesAfter(userId, id, after, size)
                : chatService.getMessages(userId, id, before, size);
        return ResponseEntity.ok(ApiResponse.success(page));
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

    /** POST /api/v1/flashcards/sets/{id}/share — chia sẻ bộ thẻ công khai cho nhiều người (follow lẫn nhau). */
    @PostMapping("/flashcards/sets/{id}/share")
    public ResponseEntity<ApiResponse<List<MessageResponse>>> shareDeck(
            @PathVariable Long id,
            @Valid @RequestBody ShareDeckRequest request) {
        List<MessageResponse> sent = chatService.shareDeck(CurrentUser.requireId(), id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã chia sẻ cho " + sent.size() + " người", sent));
    }
}
