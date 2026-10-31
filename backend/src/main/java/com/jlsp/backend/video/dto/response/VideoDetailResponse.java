package com.jlsp.backend.video.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import lombok.*;

import java.time.LocalDateTime;

/**
 * DTO phản hồi chi tiết đầy đủ của Video, bao gồm phụ đề JSON và mô tả bài học.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VideoDetailResponse {

    /**
     * ID của video
     */
    private Long id;

    /**
     * Tiêu đề video bài học
     */
    private String title;

    /**
     * Mô tả chi tiết nội dung video
     */
    private String description;

    /**
     * Đường dẫn ảnh bìa / thumbnail
     */
    private String thumbnailUrl;

    /**
     * Thời lượng (giây)
     */
    private Integer duration;

    /**
     * Cấp độ JLPT
     */
    private JLPTLevel jlptLevel;

    /** Chủ đề của video (null nếu chưa gắn). */
    private Long topicId;
    private String topicName;

    /**
     * Đường dẫn phát video
     */
    private String videoUrl;

    /**
     * Dữ liệu phụ đề tương tác định dạng JSON (chứa phân đoạn start/end, text, ruby/furigana)
     */
    private String subtitles;

    /**
     * Kết quả phân tích ngữ pháp (JSON array SegmentGrammarAnalysis), null nếu chưa phân tích xong
     */
    private String grammarAnalysis;

    /**
     * Lượt xem
     */
    private Long viewCount;

    /**
     * Lượt thích
     */
    private Integer likeCount;

    /**
     * Lượt lưu vào bộ sưu tập
     */
    private Integer saveCount;

    /**
     * Trạng thái hiển thị (PUBLIC, PRIVATE...)
     */
    private VideoStatus status;

    /**
     * Trạng thái kiểm duyệt của Moderator
     */
    private com.jlsp.backend.video.entity.VideoModStatus modStatus;

    /**
     * Thông tin người đăng (Creator)
     */
    private Long creatorId;
    private String creatorUsername;
    private String creatorDisplayName;
    private String creatorAvatarUrl;

    /**
     * Trạng thái tương tác của người dùng hiện tại
     */
    private Boolean isLiked;
    private Boolean isSaved;

    /**
     * Lý do từ chối kiểm duyệt (nếu vi phạm)
     */
    private String rejectionReason;

    /**
     * ID người duyệt / từ chối
     */
    private Long moderatedBy;

    /**
     * Thời điểm kiểm duyệt
     */
    private LocalDateTime moderatedAt;

    /**
     * Thời điểm đăng tải và cập nhật
     */
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
