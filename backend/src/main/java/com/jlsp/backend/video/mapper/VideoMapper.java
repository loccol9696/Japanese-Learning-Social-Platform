package com.jlsp.backend.video.mapper;

import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.video.dto.request.CreateVideoRequest;
import com.jlsp.backend.video.dto.response.ShadowingPracticeResponse;
import com.jlsp.backend.video.dto.response.VideoDetailResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.entity.ShadowingPractice;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoStatus;
import org.springframework.stereotype.Component;

/**
 * Mapper chịu trách nhiệm chuyển đổi dữ liệu giữa Entity và DTO cho phân hệ Video.
 * Không truy vấn DB: số liệu cần đếm (bình luận...) do service nạp gộp rồi truyền vào.
 */
@Component
public class VideoMapper {

    /**
     * Chuyển đổi từ CreateVideoRequest và User creator sang Video Entity.
     *
     * @param request DTO thông tin video tạo mới
     * @param creator Thực thể người dùng đăng tải
     * @return Video entity đã khởi tạo
     */
    public Video toEntity(CreateVideoRequest request, User creator) {
        if (request == null) {
            return null;
        }

        return Video.builder()
                .user(creator)
                .title(request.getTitle())
                .description(request.getDescription())
                .thumbnailUrl(request.getThumbnailUrl())
                .duration(request.getDuration())
                .jlptLevel(request.getJlptLevel())
                .videoUrl(request.getVideoUrl())
                .subtitles(request.getSubtitles())
                .status(request.getStatus() != null ? request.getStatus() : VideoStatus.PUBLIC)
                .modStatus((request.getStatus() == VideoStatus.PRIVATE) 
                        ? com.jlsp.backend.video.entity.VideoModStatus.APPROVED 
                        : com.jlsp.backend.video.entity.VideoModStatus.PENDING)
                .viewCount(0L)
                .likeCount(0)
                .saveCount(0)
                .build();
    }

    /**
     * Chuyển đổi Video Entity sang VideoResponse tóm tắt (dùng cho Feed danh sách).
     *
     * @param video   Entity video
     * @param isLiked      Người dùng hiện tại đã like video này chưa
     * @param isSaved      Người dùng hiện tại đã lưu video này chưa
     * @param commentCount Số bình luận của video
     * @return VideoResponse DTO
     */
    public VideoResponse toVideoResponse(Video video, Boolean isLiked, Boolean isSaved, long commentCount) {
        if (video == null) {
            return null;
        }

        User creator = video.getUser();

        return VideoResponse.builder()
                .id(video.getId())
                .title(video.getTitle())
                .thumbnailUrl(video.getThumbnailUrl())
                .duration(video.getDuration())
                .jlptLevel(video.getJlptLevel())
                .videoUrl(video.getVideoUrl())
                .viewCount(video.getViewCount())
                .likeCount(video.getLikeCount())
                .saveCount(video.getSaveCount())
                .commentCount(commentCount)
                .status(video.getStatus())
                .modStatus(video.getModStatus())
                .creatorId(creator != null ? creator.getId() : null)
                .creatorUsername(creator != null ? creator.getUsername() : null)
                .creatorDisplayName(creator != null ? creator.getDisplayName() : null)
                .creatorAvatarUrl(creator != null ? creator.getAvatarUrl() : null)
                .isLiked(isLiked != null ? isLiked : false)
                .isSaved(isSaved != null ? isSaved : false)
                .rejectionReason(video.getRejectionReason())
                .moderatedAt(video.getModeratedAt())
                .subtitles(video.getSubtitles())
                .createdAt(video.getCreatedAt())
                .build();
    }

    /**
     * Chuyển đổi Video Entity sang VideoDetailResponse đầy đủ (bao gồm phụ đề JSON và mô tả).
     *
     * @param video   Entity video
     * @param isLiked Người dùng hiện tại đã like chưa
     * @param isSaved Người dùng hiện tại đã save chưa
     * @return VideoDetailResponse DTO
     */
    public VideoDetailResponse toVideoDetailResponse(Video video, Boolean isLiked, Boolean isSaved) {
        if (video == null) {
            return null;
        }

        User creator = video.getUser();

        return VideoDetailResponse.builder()
                .id(video.getId())
                .title(video.getTitle())
                .description(video.getDescription())
                .thumbnailUrl(video.getThumbnailUrl())
                .duration(video.getDuration())
                .jlptLevel(video.getJlptLevel())
                .videoUrl(video.getVideoUrl())
                .subtitles(video.getSubtitles())
                .viewCount(video.getViewCount())
                .likeCount(video.getLikeCount())
                .saveCount(video.getSaveCount())
                .status(video.getStatus())
                .modStatus(video.getModStatus())
                .creatorId(creator != null ? creator.getId() : null)
                .creatorUsername(creator != null ? creator.getUsername() : null)
                .creatorDisplayName(creator != null ? creator.getDisplayName() : null)
                .creatorAvatarUrl(creator != null ? creator.getAvatarUrl() : null)
                .isLiked(isLiked != null ? isLiked : false)
                .isSaved(isSaved != null ? isSaved : false)
                .rejectionReason(video.getRejectionReason())
                .moderatedBy(video.getModeratedBy())
                .moderatedAt(video.getModeratedAt())
                .createdAt(video.getCreatedAt())
                .updatedAt(video.getUpdatedAt())
                .build();
    }

    /**
     * Chuyển đổi ShadowingPractice Entity sang ShadowingPracticeResponse.
     *
     * @param practice Entity bài nộp luyện tập shadowing
     * @return ShadowingPracticeResponse DTO
     */
    public ShadowingPracticeResponse toShadowingPracticeResponse(ShadowingPractice practice) {
        if (practice == null) {
            return null;
        }

        return ShadowingPracticeResponse.builder()
                .id(practice.getId())
                .userId(practice.getUser() != null ? practice.getUser().getId() : null)
                .videoId(practice.getVideo() != null ? practice.getVideo().getId() : null)
                .videoTitle(practice.getVideo() != null ? practice.getVideo().getTitle() : null)
                .audioUrl(practice.getAudioUrl())
                .score(practice.getScore())
                .feedback(practice.getFeedback())
                .createdAt(practice.getCreatedAt())
                .build();
    }
}
