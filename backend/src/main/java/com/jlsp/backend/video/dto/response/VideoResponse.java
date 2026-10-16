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

    /**
     * Trạng thái hiển thị (PUBLIC, PRIVATE...)
     */
    private VideoStatus status;

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
     * Thời điểm đăng tải
     */
    private LocalDateTime createdAt;
}
