package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDateTime;

/**
 * Một lượt đánh giá "hữu ích" của người dùng cho bình luận. Bình luận đã xóa mềm thì lượt đánh giá
 * ẩn theo nó và quay lại khi khôi phục; bình luận bị xóa hẳn thì DB tự xóa lượt đánh giá.
 */
@Entity
@Table(name = "comment_likes", indexes = {
        @Index(name = "idx_comment_likes_comment", columnList = "comment_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CommentLike {

    /**
     * Khóa chính kết hợp (user_id, comment_id)
     */
    @EmbeddedId
    private CommentLikeId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("commentId")
    @JoinColumn(name = "comment_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private VideoComment comment;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
