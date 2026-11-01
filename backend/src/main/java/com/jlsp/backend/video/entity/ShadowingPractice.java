package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Entity đại diện cho bảng 'shadowing_practice' trong cơ sở dữ liệu.
 * Quản lý các bài nộp luyện nói (Shadowing) của học viên theo video bài học.
 * 
 * Khung AI-Ready:
 * - 'audioUrl' lưu file ghi âm giọng đọc của học viên.
 * - 'score' (thang điểm 0 - 100.00) và 'feedback' (nhận xét phát âm / pitch accent)
 *   được để trống (null) khi học viên mới nộp bài, sẵn sàng để module AI đánh giá và cập nhật sau.
 */
@Entity
@Table(name = "shadowing_practice")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLRestriction("deleted_at IS NULL")
public class ShadowingPractice {

    /**
     * Khóa chính của bài luyện tập (Tương ứng practice_id trong ERD)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Học viên thực hiện bài luyện nói
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * Video bài học mà học viên đang luyện tập nhại theo
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "video_id", nullable = false)
    private Video video;

    /**
     * Đường dẫn file ghi âm giọng nói của học viên (URL Cloud Storage)
     */
    @Column(name = "audio_url", nullable = false, length = 255)
    private String audioUrl;

    /**
     * Điểm số phát âm (0.00 - 100.00) do AI đánh giá.
     * Mặc định là null khi mới nộp, chờ AI chấm điểm.
     */
    @Column(precision = 5, scale = 2)
    private BigDecimal score;

    /**
     * Phản hồi / Nhận xét chi tiết về ngữ điệu, trọng âm (Pitch Accent) do AI tạo.
     * Mặc định là null khi mới nộp, chờ AI tạo phản hồi.
     */
    @Column(columnDefinition = "TEXT")
    private String feedback;

    /**
     * Thời điểm học viên nộp bài luyện tập
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
