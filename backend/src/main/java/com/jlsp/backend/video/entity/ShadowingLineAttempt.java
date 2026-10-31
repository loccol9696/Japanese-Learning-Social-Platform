package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.time.LocalDateTime;

/** Một lần luyện nói nhại theo cho một dòng phụ đề của video. */
@Entity
@Table(name = "shadowing_line_attempts", indexes = {
        @Index(name = "idx_shadowing_line_user_video", columnList = "user_id, video_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLRestriction("deleted_at IS NULL")
public class ShadowingLineAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "video_id", nullable = false)
    private Video video;

    @Column(name = "line_index", nullable = false)
    private Integer lineIndex;

    @Column(name = "expected_text", nullable = false, length = 1000)
    private String expectedText;

    @Column(name = "recognized_text", length = 1000)
    private String recognizedText;

    @Column(nullable = false)
    private Integer score;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();

    /** Thời điểm xóa mềm, trùng với video chứa nó; NULL = chưa xóa. */
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}
