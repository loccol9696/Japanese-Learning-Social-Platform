package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CreateVideoRequest;
import com.jlsp.backend.video.dto.request.ShadowingSubmissionRequest;
import com.jlsp.backend.video.dto.request.UpdateVideoRequest;
import com.jlsp.backend.video.dto.response.ShadowingPracticeResponse;
import com.jlsp.backend.video.dto.response.VideoDetailResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.entity.*;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import com.jlsp.backend.video.service.VideoService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import java.time.LocalDateTime;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Lớp cài đặt (Implementation) toàn bộ nghiệp vụ xử lý cho Video học tiếng
 * Nhật.
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class VideoServiceImpl implements VideoService {

    private final VideoRepository videoRepository;
    private final VideoLikeRepository videoLikeRepository;
    private final VideoSaveRepository videoSaveRepository;
    private final ShadowingPracticeRepository shadowingPracticeRepository;
    private final UserRepository userRepository;
    private final FollowRepository followRepository;
    private final VideoMapper videoMapper;

    /**
     * Đăng tải bài học video mới.
     * Khởi tạo các số liệu thống kê ban đầu (0 view, 0 like, 0 save).
     */
    @Override
    @Transactional
    public VideoDetailResponse createVideo(Long currentUserId, CreateVideoRequest request) {
        log.info("Bắt đầu tạo video mới bởi user ID: {}", currentUserId);

        // 1. Tìm thông tin Creator
        User creator = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        // 2. Chuyển đổi DTO sang Entity và lưu DB
        Video video = videoMapper.toEntity(request, creator);
        Video savedVideo = videoRepository.save(video);

        log.info("Tạo video thành công với ID: {}", savedVideo.getId());
        return videoMapper.toVideoDetailResponse(savedVideo, false, false);
    }

    /**
     * Lấy chi tiết một video kèm kiểm tra trạng thái tương tác Like/Save của người
     * dùng.
     */
    @Override
    public VideoDetailResponse getVideoById(Long id, Long currentUserId) {
        Video video = videoRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", id));

        // Kiểm tra quyền riêng tư: nếu video là PRIVATE thì chỉ chủ sở hữu mới xem được
        if (video.getStatus() == VideoStatus.PRIVATE) {
            if (currentUserId == null || !video.getUser().getId().equals(currentUserId)) {
                throw new AppException(403, "Video này đang ở chế độ riêng tư");
            }
        }

        boolean isLiked = false;
        boolean isSaved = false;

        if (currentUserId != null) {
            isLiked = videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);
            isSaved = videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);
        }

        return videoMapper.toVideoDetailResponse(video, isLiked, isSaved);
    }

    /**
     * Cập nhật thông tin video (tiêu đề, mô tả, JLPT level, thumbnail, status).
     * Chỉ người tạo (hoặc Admin) mới có quyền chỉnh sửa.
     */
    @Override
    @Transactional
    public VideoDetailResponse updateVideo(Long id, Long currentUserId, UpdateVideoRequest request) {
        Video video = videoRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", id));

        // Kiểm tra quyền sở hữu
        validateOwnership(video, currentUserId);

        // Cập nhật các trường có thay đổi
        if (request.getTitle() != null && !request.getTitle().isBlank()) {
            video.setTitle(request.getTitle());
        }
        if (request.getDescription() != null) {
            video.setDescription(request.getDescription());
        }
        if (request.getThumbnailUrl() != null && !request.getThumbnailUrl().isBlank()) {
            video.setThumbnailUrl(request.getThumbnailUrl());
        }
        if (request.getJlptLevel() != null) {
            video.setJlptLevel(request.getJlptLevel());
        }
        if (request.getStatus() != null) {
            // Nếu người dùng chuyển video từ PRIVATE/UNLISTED sang PUBLIC thì cần Moderator duyệt (PENDING)
            if (video.getStatus() != VideoStatus.PUBLIC && request.getStatus() == VideoStatus.PUBLIC) {
                video.setModStatus(com.jlsp.backend.video.entity.VideoModStatus.PENDING);
                video.setModeratedBy(null);
                video.setModeratedAt(null);
                video.setRejectionReason(null);
                log.info("Video ID {} chuyển sang PUBLIC -> Đặt trạng thái PENDING chờ Moderator duyệt", id);
            }
            video.setStatus(request.getStatus());
        }

        Video updated = videoRepository.save(video);
        boolean isLiked = videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);
        boolean isSaved = videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);

        log.info("Cập nhật video ID: {} thành công bởi user ID: {}", id, currentUserId);
        return videoMapper.toVideoDetailResponse(updated, isLiked, isSaved);
    }

    /**
     * Xóa video khỏi hệ thống.
     */
    @Override
    @Transactional
    public void deleteVideo(Long id, Long currentUserId) {
        Video video = videoRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", id));

        validateOwnership(video, currentUserId);

        videoRepository.delete(video);
        log.info("Xóa video ID: {} thành công bởi user ID: {}", id, currentUserId);
    }

    /**
     * Lấy danh sách video đề xuất "Dành cho bạn" (For-You Feed).
     * Tự động lọc theo cấp độ JLPT nếu có yêu cầu.
     */
    @Override
    public PageResponse<VideoResponse> getForYouFeed(Long currentUserId, JLPTLevel jlptLevel, Pageable pageable) {
        Page<Video> page;

        if (jlptLevel != null) {
            // Lọc video theo cấp độ JLPT chỉ định đã được duyệt
            page = videoRepository.findByStatusAndModStatusAndJlptLevel(VideoStatus.PUBLIC, VideoModStatus.APPROVED, jlptLevel, pageable);
        } else {
            // Lấy tất cả video công khai đã được duyệt
            page = videoRepository.findByStatusAndModStatus(VideoStatus.PUBLIC, VideoModStatus.APPROVED, pageable);
        }

        List<VideoResponse> responseList = page.getContent().stream()
                .map(v -> {
                    boolean isLiked = currentUserId != null
                            && videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    boolean isSaved = currentUserId != null
                            && videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    return videoMapper.toVideoResponse(v, isLiked, isSaved);
                })
                .collect(Collectors.toList());

        return PageResponse.<VideoResponse>builder()
                .content(responseList)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    /**
     * Lấy danh sách video từ những Creator mà người dùng đang theo dõi (Following
     * Feed).
     */
    @Override
    public PageResponse<VideoResponse> getFollowingFeed(Long currentUserId, Pageable pageable) {
        // 1. Lấy danh sách creator ID mà user đang theo dõi
        List<Long> followingIds = followRepository.findFollowingIdsByFollowerId(currentUserId);

        if (followingIds == null || followingIds.isEmpty()) {
            return PageResponse.<VideoResponse>builder()
                    .content(Collections.emptyList())
                    .page(pageable.getPageNumber())
                    .size(pageable.getPageSize())
                    .totalElements(0L)
                    .totalPages(0)
                    .last(true)
                    .build();
        }

        // 2. Truy vấn video công khai của các creator đó đã được duyệt
        Page<Video> page = videoRepository.findByUserIdInAndStatusAndModStatus(followingIds, VideoStatus.PUBLIC, com.jlsp.backend.video.entity.VideoModStatus.APPROVED, pageable);

        List<VideoResponse> responseList = page.getContent().stream()
                .map(v -> {
                    boolean isLiked = videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    boolean isSaved = videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    return videoMapper.toVideoResponse(v, isLiked, isSaved);
                })
                .collect(Collectors.toList());

        return PageResponse.<VideoResponse>builder()
                .content(responseList)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    /**
     * Lấy danh sách video của một Creator cụ thể.
     */
    @Override
    public PageResponse<VideoResponse> getVideosByUserId(Long userId, Long currentUserId, Pageable pageable) {
        Page<Video> page;

        // Nếu người xem chính là chủ tài khoản -> xem được cả video Private/Unlisted
        if (currentUserId != null && currentUserId.equals(userId)) {
            page = videoRepository.findByUserId(userId, pageable);
        } else {
            page = videoRepository.findByUserIdAndStatus(userId, VideoStatus.PUBLIC, pageable);
        }

        List<VideoResponse> responseList = page.getContent().stream()
                .map(v -> {
                    boolean isLiked = currentUserId != null
                            && videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    boolean isSaved = currentUserId != null
                            && videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, v.getId());
                    return videoMapper.toVideoResponse(v, isLiked, isSaved);
                })
                .collect(Collectors.toList());

        return PageResponse.<VideoResponse>builder()
                .content(responseList)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    /**
     * Thả tim hoặc Bỏ thích video (Toggle Like).
     * Tự động tăng/giảm like_count trên video một cách nguyên tử.
     */
    @Override
    @Transactional
    public boolean toggleLike(Long videoId, Long currentUserId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        VideoLikeId likeId = new VideoLikeId(currentUserId, videoId);

        if (videoLikeRepository.existsById(likeId)) {
            // Đã like -> Huỷ like
            videoLikeRepository.deleteById(likeId);
            videoRepository.updateLikeCount(videoId, -1);
            log.info("User ID: {} đã UNLIKE video ID: {}", currentUserId, videoId);
            return false;
        } else {
            // Chưa like -> Tạo like mới
            VideoLike like = VideoLike.builder()
                    .id(likeId)
                    .user(user)
                    .video(video)
                    .build();
            videoLikeRepository.save(like);
            videoRepository.updateLikeCount(videoId, 1);
            log.info("User ID: {} đã LIKE video ID: {}", currentUserId, videoId);
            return true;
        }
    }

    /**
     * Lưu hoặc Bỏ lưu video vào bộ sưu tập cá nhân (Toggle Save).
     * Tự động tăng/giảm save_count trên video một cách nguyên tử.
     */
    @Override
    @Transactional
    public boolean toggleSave(Long videoId, Long currentUserId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        VideoSaveId saveId = new VideoSaveId(currentUserId, videoId);

        if (videoSaveRepository.existsById(saveId)) {
            // Đã lưu -> Huỷ lưu
            videoSaveRepository.deleteById(saveId);
            videoRepository.updateSaveCount(videoId, -1);
            log.info("User ID: {} đã UNSAVE video ID: {}", currentUserId, videoId);
            return false;
        } else {
            // Chưa lưu -> Tạo bookmark mới
            VideoSave save = VideoSave.builder()
                    .id(saveId)
                    .user(user)
                    .video(video)
                    .build();
            videoSaveRepository.save(save);
            videoRepository.updateSaveCount(videoId, 1);
            log.info("User ID: {} đã SAVE video ID: {}", currentUserId, videoId);
            return true;
        }
    }

    /**
     * Tăng số lượt xem (View Count) của video.
     */
    @Override
    @Transactional
    public void incrementViewCount(Long videoId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        videoRepository.incrementViewCount(videoId);
    }

    /**
     * Cập nhật dữ liệu phụ đề tương tác JSON (chứa phân đoạn start/end, text,
     * ruby/furigana).
     * Khung sẵn sàng tiếp nhận kết quả từ module AI trích xuất lời thoại tiếng
     * Nhật.
     */
    @Override
    @Transactional
    public VideoDetailResponse updateSubtitles(Long videoId, Long currentUserId, String subtitlesJson) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        // Chỉ chủ sở hữu hoặc admin mới có quyền nạp phụ đề
        validateOwnership(video, currentUserId);

        video.setSubtitles(subtitlesJson);
        Video updated = videoRepository.save(video);

        boolean isLiked = videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, videoId);
        boolean isSaved = videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, videoId);

        log.info("Cập nhật phụ đề thành công cho video ID: {}", videoId);
        return videoMapper.toVideoDetailResponse(updated, isLiked, isSaved);
    }

    /**
     * Nộp bài luyện nói nhại theo (Shadowing Practice).
     * Lưu bản ghi bài nộp với audioUrl, để ngỏ score và feedback cho AI chấm sau.
     */
    @Override
    @Transactional
    public ShadowingPracticeResponse submitShadowing(Long videoId, Long currentUserId,
            ShadowingSubmissionRequest request) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        // Tạo bài luyện tập (score và feedback để null chờ module AI xử lý)
        ShadowingPractice practice = ShadowingPractice.builder()
                .video(video)
                .user(user)
                .audioUrl(request.getAudioUrl())
                .score(null) // Khung chờ AI chấm điểm phát âm
                .feedback(null) // Khung chờ AI nhận xét trọng âm
                .build();

        ShadowingPractice saved = shadowingPracticeRepository.save(practice);
        log.info("User ID: {} đã nộp bài Shadowing ID: {} cho video ID: {}", currentUserId, saved.getId(), videoId);

        return videoMapper.toShadowingPracticeResponse(saved);
    }

    /**
     * Lấy lịch sử nộp bài luyện nói Shadowing của học viên đối với video này.
     */
    @Override
    public List<ShadowingPracticeResponse> getShadowingHistory(Long videoId, Long currentUserId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }

        List<ShadowingPractice> practices = shadowingPracticeRepository
                .findByVideoIdAndUserIdOrderByCreatedAtDesc(videoId, currentUserId);
        return practices.stream()
                .map(videoMapper::toShadowingPracticeResponse)
                .collect(Collectors.toList());
    }

    /**
     * Lấy danh sách video tổng hợp
     */
    @Override
    public PageResponse<VideoResponse> getAllVideos(Long currentUserId, String feed, JLPTLevel jlptLevel, Long userId,
            Pageable pageable) {
        if (userId != null) {
            return getVideosByUserId(userId, currentUserId, pageable);
        }
        if ("following".equalsIgnoreCase(feed)) {
            return getFollowingFeed(currentUserId, pageable);
        }
        return getForYouFeed(currentUserId, jlptLevel, pageable);
    }

    /**
     * Thả tim (Like) video
     */
    @Override
    @Transactional
    public void likeVideo(Long videoId, Long currentUserId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        VideoLikeId likeId = new VideoLikeId(currentUserId, videoId);

        if (!videoLikeRepository.existsById(likeId)) {
            VideoLike like = VideoLike.builder()
                    .id(likeId)
                    .user(user)
                    .video(video)
                    .build();
            videoLikeRepository.save(like);
            videoRepository.updateLikeCount(videoId, 1);
            log.info("User ID: {} đã LIKE video ID: {}", currentUserId, videoId);
        }
    }

    /**
     * Bỏ thích (Unlike) video
     */
    @Override
    @Transactional
    public void unlikeVideo(Long videoId, Long currentUserId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }

        VideoLikeId likeId = new VideoLikeId(currentUserId, videoId);

        if (videoLikeRepository.existsById(likeId)) {
            videoLikeRepository.deleteById(likeId);
            videoRepository.updateLikeCount(videoId, -1);
            log.info("User ID: {} đã UNLIKE video ID: {}", currentUserId, videoId);
        }
    }

    /**
     * Lưu video vào bộ sưu tập cá nhân (Save)
     */
    @Override
    @Transactional
    public void saveVideo(Long videoId, Long currentUserId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        VideoSaveId saveId = new VideoSaveId(currentUserId, videoId);

        if (!videoSaveRepository.existsById(saveId)) {
            VideoSave save = VideoSave.builder()
                    .id(saveId)
                    .user(user)
                    .video(video)
                    .build();
            videoSaveRepository.save(save);
            videoRepository.updateSaveCount(videoId, 1);
            log.info("User ID: {} đã SAVE video ID: {}", currentUserId, videoId);
        }
    }

    /**
     * Bỏ lưu video khỏi bộ sưu tập (Unsave)
     */
    @Override
    @Transactional
    public void unsaveVideo(Long videoId, Long currentUserId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }

        VideoSaveId saveId = new VideoSaveId(currentUserId, videoId);

        if (videoSaveRepository.existsById(saveId)) {
            videoSaveRepository.deleteById(saveId);
            videoRepository.updateSaveCount(videoId, -1);
            log.info("User ID: {} đã UNSAVE video ID: {}", currentUserId, videoId);
        }
    }

    /**
     * Lấy phụ đề tương tác JSON của một video.
     */
    @Override
    public String getSubtitles(Long videoId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        return video.getSubtitles();
    }

    /**
     * Phương thức kiểm tra quyền sở hữu video:
     * Người thực hiện phải là chủ nhân của video hoặc có vai trò ADMIN.
     */
    private void validateOwnership(Video video, Long currentUserId) {
        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));

        boolean isOwner = video.getUser().getId().equals(currentUserId);
        boolean isAdmin = user.getRole() == UserRole.ADMIN;

        if (!isOwner && !isAdmin) {
            throw new AppException(403, "Bạn không có quyền thao tác trên video này");
        }
    }

    @Override
    @Transactional
    public VideoDetailResponse approveVideo(Long videoId, Long moderatorId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        if (video.getStatus() != VideoStatus.PUBLIC) {
            throw new AppException(400, "Chỉ có thể phê duyệt video ở chế độ công khai (PUBLIC)");
        }

        video.setModStatus(com.jlsp.backend.video.entity.VideoModStatus.APPROVED);
        video.setModeratedBy(moderatorId);
        video.setModeratedAt(LocalDateTime.now());
        video.setRejectionReason(null);

        Video saved = videoRepository.save(video);
        log.info("Moderator ID {} đã DUYỆT video ID {}", moderatorId, videoId);
        return videoMapper.toVideoDetailResponse(saved, false, false);
    }

    @Override
    @Transactional
    public VideoDetailResponse rejectVideo(Long videoId, Long moderatorId, String rejectionReason) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));

        if (video.getStatus() != VideoStatus.PUBLIC) {
            throw new AppException(400, "Chỉ có thể xử lý video ở chế độ công khai (PUBLIC)");
        }

        video.setModStatus(com.jlsp.backend.video.entity.VideoModStatus.REJECTED);
        video.setModeratedBy(moderatorId);
        video.setModeratedAt(LocalDateTime.now());
        video.setRejectionReason(rejectionReason != null && !rejectionReason.isBlank() 
                ? rejectionReason 
                : "Vi phạm tiêu chuẩn cộng đồng hoặc chất lượng nội dung");

        Video saved = videoRepository.save(video);
        log.info("Moderator ID {} đã TỪ CHỐI video ID {} với lý do: {}", moderatorId, videoId, video.getRejectionReason());
        return videoMapper.toVideoDetailResponse(saved, false, false);
    }

    @Override
    public PageResponse<VideoResponse> getModerationVideos(com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable) {
        com.jlsp.backend.video.entity.VideoModStatus targetStatus = modStatus != null ? modStatus : com.jlsp.backend.video.entity.VideoModStatus.PENDING;
        // Moderator CHỈ kiểm duyệt các video ở chế độ công khai (PUBLIC)
        Page<Video> page = videoRepository.findByStatusAndModStatus(VideoStatus.PUBLIC, targetStatus, pageable);

        List<VideoResponse> responseList = page.getContent().stream()
                .map(v -> videoMapper.toVideoResponse(v, false, false))
                .collect(Collectors.toList());

        return PageResponse.<VideoResponse>builder()
                .content(responseList)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    public PageResponse<VideoResponse> getMyVideosStatus(Long userId, Pageable pageable) {
        Page<Video> page = videoRepository.findByUserId(userId, pageable);

        List<VideoResponse> responseList = page.getContent().stream()
                .map(v -> videoMapper.toVideoResponse(v, false, false))
                .collect(Collectors.toList());

        return PageResponse.<VideoResponse>builder()
                .content(responseList)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }
}
