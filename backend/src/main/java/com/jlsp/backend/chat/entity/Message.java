package com.jlsp.backend.chat.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "messages",
        indexes = @Index(name = "idx_message_conversation_id", columnList = "conversation_id, id"),
        uniqueConstraints = @UniqueConstraint(name = "uk_message_sender_client_id",
                columnNames = {"sender_id", "client_msg_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MessageType type;

    /**
     * Nội dung văn bản (TEXT) hoặc lời nhắn kèm video (VIDEO_SHARE, có thể trống)
     */
    @Column(columnDefinition = "TEXT")
    private String content;

    /**
     * Video được chia sẻ. Không đặt khóa ngoại để việc xoá video không bị chặn;
     * video đã xoá sẽ hiển thị là "không còn khả dụng".
     */
    @Column(name = "video_id")
    private Long videoId;

    /**
     * Bộ thẻ được chia sẻ (DECK_SHARE). Không đặt khóa ngoại để việc xoá bộ thẻ không bị chặn;
     * bộ thẻ đã xoá sẽ hiển thị là "không còn khả dụng".
     */
    @Column(name = "deck_id")
    private Long deckId;

    /**
     * Mốc thời gian (ms) để mở video đúng câu phụ đề được chia sẻ
     */
    @Column(name = "video_start_ms")
    private Integer videoStartMs;

    /**
     * ID do client sinh ra để chống gửi trùng khi mạng chập chờn / gửi lại
     */
    @Column(name = "client_msg_id", length = 64)
    private String clientMsgId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
