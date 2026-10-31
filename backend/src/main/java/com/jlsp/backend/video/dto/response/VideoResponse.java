package com.jlsp.backend.video.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import lombok.*;

import java.time.LocalDateTime;

/**
 * DTO phản hồi thông tin tóm tắt của Video (sử dụng trong Feed danh sách, tìm kiếm).
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VideoResponse {

    /**
     * ID của video
     */
    private Long id;

    /**
     * Tiêu đề video bài học
     */
    private String title;

    /**
     * Đường dẫn ảnh bìa / thumbnail
     */
    private String thumbnailUrl;

    /**
     * Thời lượng (giây)
     */
    private Integer duration;

    /**
     * Cấp độ JLPT (N5 - N1)
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

    private Long commentCount;

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
     * Trạng thái tương tác của người dùng hiện tại (nếu đã đăng nhập)
     */
    private Boolean isLiked;
    private Boolean isSaved;

    /**
     * Người dùng hiện tại đang theo dõi Creator hay không
     */
    private Boolean isFollowing;

    /**
     * Lý do từ chối (nếu bị từ chối)
     */
    private String rejectionReason;

    /**
     * Thời điểm kiểm duyệt
     */
    private LocalDateTime moderatedAt;

    /**
     * Dữ liệu phụ đề
     */
    private String subtitles;

    /**
     * Kết quả phân tích ngữ pháp của AI (JSON)
     */
    private String grammarAnalysis;

    /**
     * Thời điểm đăng tải
     */
    private LocalDateTime createdAt;

    /**
     * Thời điểm chuyển vào thùng rác (chỉ có ở danh sách thùng rác)
     */
    private LocalDateTime deletedAt;

    /**
     * Thời điểm video sẽ bị xóa hẳn (chỉ có ở danh sách thùng rác)
     */
    private LocalDateTime purgeAt;
}
