package com.jlsp.backend.video.entity;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "videos")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Video {

    /**
     * Khóa chính của video (Tương ứng video_id trong ERD)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Người đăng tải / Creator của video
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * Tiêu đề video bài học
     */
    @Column(nullable = false, length = 255)
    private String title;

    /**
     * Mô tả chi tiết nội dung video bài học
     */
    @Column(columnDefinition = "TEXT")
    private String description;

    /**
     * Đường dẫn ảnh bìa / thumbnail của video
     */
    @Column(name = "thumbnail_url", nullable = false, length = 255)
    private String thumbnailUrl;

    /**
     * Thời lượng video tính bằng giây
     */
    @Column(nullable = false)
    private Integer duration;

    /**
     * Cấp độ JLPT tương ứng với độ khó của bài học (N5, N4, N3, N2, N1)
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "jlpt_level", nullable = false, length = 10)
    private JLPTLevel jlptLevel;

    /**
     * Đường dẫn phát video (file MP4 hoặc HLS stream .m3u8)
     */
    @Column(name = "video_url", nullable = false, length = 255)
    private String videoUrl;

    /**
     * Dữ liệu phụ đề tương tác định dạng JSON.
     * Cột này được thiết kế để nhận output từ AI (Whisper + Kuromoji)
     * chứa timestamps (start_ms, end_ms), văn bản tiếng Nhật và chú thích
     * Ruby/Furigana.
     */
    @Column(columnDefinition = "TEXT")
    private String subtitles;

    /**
     * Tổng số lượt xem hợp lệ
     */
    @Column(name = "view_count", nullable = false)
    @Builder.Default
    private Long viewCount = 0L;

    /**
     * Tổng số lượt thích (Like)
     */
    @Column(name = "like_count", nullable = false)
    @Builder.Default
    private Integer likeCount = 0;

    /**
     * Tổng số lượt lưu vào bộ sưu tập (Bookmark/Save)
     */
    @Column(name = "save_count", nullable = false)
    @Builder.Default
    private Integer saveCount = 0;

    /**
     * Trạng thái hiển thị của video (PUBLIC, PRIVATE, UNLISTED)
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private VideoStatus status = VideoStatus.PUBLIC;

    /**
     * Thời điểm đăng tải
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Thời điểm cập nhật thông tin gần nhất
     */
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.viewCount == null) {
            this.viewCount = 0L;
        }
        if (this.likeCount == null) {
            this.likeCount = 0;
        }
        if (this.saveCount == null) {
            this.saveCount = 0;
        }
        if (this.status == null) {
            this.status = VideoStatus.PUBLIC;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
