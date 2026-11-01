package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.time.LocalDateTime;

@Entity
@Table(name = "video_likes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLRestriction("deleted_at IS NULL")
public class VideoLike {

    /**
     * Khóa chính kết hợp (user_id, video_id)
     */
    @EmbeddedId
    private VideoLikeId id;

    /**
     * Người dùng thực hiện thả tim
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * Video nhận lượt thả tim
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("videoId")
    @JoinColumn(name = "video_id", nullable = false)
    private Video video;

    /**
     * Thời điểm thả tim
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Thời điểm xóa mềm, trùng với video chứa nó; NULL = chưa xóa.
     */
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
