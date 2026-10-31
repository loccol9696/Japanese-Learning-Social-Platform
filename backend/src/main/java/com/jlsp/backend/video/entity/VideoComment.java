package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.SQLRestriction;

import java.time.LocalDateTime;

@Entity
@Table(name = "video_comments", indexes = {
        @Index(name = "idx_video_comments_video", columnList = "video_id"),
        @Index(name = "idx_video_comments_parent", columnList = "parent_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLRestriction("deleted_at IS NULL")
public class VideoComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "video_id", nullable = false)
    private Video video;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private VideoComment parent;

    /** Bình luận mà câu này trả lời: chính là {@link #parent} khi trả lời bình luận gốc, hoặc một phản hồi khác khi trả lời phản hồi. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reply_to_id")
    private VideoComment replyTo;

    @Column(nullable = false, length = 1000)
    private String content;

    /** Số lượt đánh giá hữu ích. Có default ở DB để ddl-auto thêm được cột vào bảng đã có dữ liệu. */
    @Column(name = "like_count", nullable = false)
    @ColumnDefault("0")
    @Builder.Default
    private Integer likeCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /** Thời điểm xóa mềm, trùng với video chứa nó; NULL = chưa xóa. */
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
