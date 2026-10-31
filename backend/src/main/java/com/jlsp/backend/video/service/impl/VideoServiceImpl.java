package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.repository.IdCount;
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
import com.jlsp.backend.video.event.SubtitlesUpdatedEvent;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import com.jlsp.backend.video.service.ForYouRanker;
import com.jlsp.backend.video.service.VideoService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import java.time.LocalDateTime;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
    private final VideoCommentRepository videoCommentRepository;
    private final ShadowingPracticeRepository shadowingPracticeRepository;
    private final UserRepository userRepository;
    private final FollowRepository followRepository;
    private final VideoMapper videoMapper;
    private final com.jlsp.backend.topic.service.TopicService topicService;
    private final com.jlsp.backend.notification.service.NotificationService notificationService;
    private final com.jlsp.backend.block.service.BlockService blockService;
    private final com.jlsp.backend.common.security.ratelimit.RateLimiter rateLimiter;

    /** Một người xem chỉ được tính một lượt xem cho mỗi video trong khoảng này. */
    static final java.time.Duration VIEW_DEDUP_WINDOW = java.time.Duration.ofMinutes(30);
    private final ApplicationEventPublisher eventPublisher;

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
        com.jlsp.backend.topic.entity.Topic topic = request.getTopicId() != null
                ? topicService.requireActive(request.getTopicId())
                : null;
        Video video = videoMapper.toEntity(request, creator, topic);
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
        if (video.getStatus() == VideoStatus.PRIVATE || video.getStatus() == VideoStatus.DRAFT) {
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

        // Cập nhật các trường có thay đổi; ghi nhận việc nội dung hiển thị có đổi thật không
        boolean contentChanged = false;
        if (request.getTitle() != null && !request.getTitle().isBlank()) {
            contentChanged |= !request.getTitle().trim().equals(video.getTitle() == null ? "" : video.getTitle().trim());
            video.setTitle(request.getTitle());
        }
        if (request.getDescription() != null) {
            // null và chuỗi rỗng đều nghĩa là "không có mô tả"
            String before = video.getDescription() == null ? "" : video.getDescription().trim();
            contentChanged |= !request.getDescription().trim().equals(before);
            video.setDescription(request.getDescription());
        }
        if (request.getThumbnailUrl() != null && !request.getThumbnailUrl().isBlank()) {
            contentChanged |= !request.getThumbnailUrl().equals(video.getThumbnailUrl());
            video.setThumbnailUrl(request.getThumbnailUrl());
        }
        if (request.getJlptLevel() != null) {
            video.setJlptLevel(request.getJlptLevel());
        }
        if (request.getTopicId() != null) {
            // Số không/âm nghĩa là bỏ chủ đề; ngược lại phải là chủ đề đang hiển thị.
            video.setTopic(request.getTopicId() > 0 ? topicService.requireActive(request.getTopicId()) : null);
        }
        boolean subtitlesChanged = false;
        if (request.getSubtitles() != null) {
            String trimmedSub = request.getSubtitles().trim();
            String normalizedSub = trimmedSub.isEmpty() ? null : trimmedSub;
            subtitlesChanged = !java.util.Objects.equals(normalizedSub, video.getSubtitles());
            video.setSubtitles(normalizedSub);
            if (subtitlesChanged && request.getGrammarAnalysis() == null) {
                video.setGrammarAnalysis(null);
            }
        }
        if (request.getGrammarAnalysis() != null) {
            String trimmedGa = request.getGrammarAnalysis().trim();
            video.setGrammarAnalysis(trimmedGa.isEmpty() ? null : trimmedGa);
        }
        if (request.getStatus() != null) {
            if (request.getStatus() == VideoStatus.DRAFT) {
                video.setModStatus(VideoModStatus.DRAFT);
            } else if (request.getStatus() == VideoStatus.PRIVATE) {
                video.setModStatus(VideoModStatus.APPROVED);
            } else if (video.getStatus() != VideoStatus.PUBLIC && request.getStatus() == VideoStatus.PUBLIC) {
                // Chuyển từ DRAFT/PRIVATE/UNLISTED sang PUBLIC -> cần Moderator duyệt (PENDING)
                video.setModStatus(VideoModStatus.PENDING);
                video.setModeratedBy(null);
                video.setModeratedAt(null);
                video.setRejectionReason(null);
                log.info("Video ID {} chuyển sang PUBLIC -> Đặt trạng thái PENDING chờ Moderator duyệt", id);
            }
            video.setStatus(request.getStatus());
        }

        // Sửa tiêu đề / mô tả / ảnh bìa của video công khai đã qua kiểm duyệt (hoặc đã bị từ chối)
        // thì phải được duyệt lại, nếu không người đăng có thể đổi sang nội dung vi phạm sau khi được duyệt.
        if (contentChanged && video.getStatus() == VideoStatus.PUBLIC
                && video.getModStatus() != VideoModStatus.PENDING) {
            video.setModStatus(VideoModStatus.PENDING);
            video.setModeratedBy(null);
            video.setModeratedAt(null);
            video.setRejectionReason(null);
            log.info("Video ID {} đổi nội dung -> Đặt trạng thái PENDING chờ Moderator duyệt lại", id);
        }

        Video updated = videoRepository.save(video);
        boolean isLiked = videoLikeRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);
        boolean isSaved = videoSaveRepository.existsByIdUserIdAndIdVideoId(currentUserId, id);

        log.info("Cập nhật video ID: {} thành công bởi user ID: {}", id, currentUserId);
        return videoMapper.toVideoDetailResponse(updated, isLiked, isSaved);
    }

    /**
     * Lấy danh sách video đề xuất "Dành cho bạn" (For-You Feed).
     * Tự động lọc theo cấp độ JLPT nếu có yêu cầu.
     */
    @Override
    public PageResponse<VideoResponse> getForYouFeed(Long currentUserId, JLPTLevel jlptLevel, Pageable pageable) {
        Page<Video> page;

        List<Long> excluded = excludedAuthorIds(currentUserId);
        if (jlptLevel != null) {
            // Lọc video theo cấp độ JLPT chỉ định đã được duyệt
            page = videoRepository.findFeedByJlptLevel(VideoStatus.PUBLIC, VideoModStatus.APPROVED, jlptLevel, excluded, pageable);
        } else {
            // Lấy tất cả video công khai đã được duyệt
            page = videoRepository.findFeed(VideoStatus.PUBLIC, VideoModStatus.APPROVED, excluded, pageable);
        }

        return toVideoPageResponse(page, currentUserId);
    }

    /** Số video mới nhất được đưa vào xếp hạng; đủ rộng để có lựa chọn, đủ nhỏ để xếp trong bộ nhớ. */
    static final int RECOMMEND_POOL_SIZE = 400;

    /**
     * Feed "Dành cho bạn" theo trình độ và sở thích người dùng đã chọn ở câu hỏi chào mừng.
     * Chưa đăng nhập hoặc chưa có sở thích thì dùng feed thường.
     */
    @Override
    public PageResponse<VideoResponse> getRecommendedFeed(Long currentUserId, Pageable pageable) {
        User viewer = currentUserId == null ? null : userRepository.findById(currentUserId).orElse(null);
        ForYouRanker.Preferences prefs = viewer == null ? null : new ForYouRanker.Preferences(
                viewer.getJlptLevel(),
                viewer.getTopics().stream().map(t -> t.getId()).collect(Collectors.toSet()));
        if (prefs == null || prefs.isEmpty()) {
            return getForYouFeed(currentUserId, null, pageable);
        }

        Page<Video> pool = videoRepository.findFeed(VideoStatus.PUBLIC, VideoModStatus.APPROVED,
                excludedAuthorIds(currentUserId),
                org.springframework.data.domain.PageRequest.of(0, RECOMMEND_POOL_SIZE,
                        org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "createdAt")));
        List<Video> ranked = ForYouRanker.rank(pool.getContent(), prefs, LocalDateTime.now());

        long from = Math.min(pageable.getOffset(), ranked.size());
        long to = Math.min(from + pageable.getPageSize(), ranked.size());
        Pageable plain = org.springframework.data.domain.PageRequest.of(pageable.getPageNumber(), pageable.getPageSize());
        return toVideoPageResponse(new org.springframework.data.domain.PageImpl<>(
                ranked.subList((int) from, (int) to), plain, ranked.size()), currentUserId);
    }

    /**
     * Id tác giả bị loại khỏi feed của người xem (mình chặn họ hoặc họ chặn mình). Luôn khác rỗng
     * vì mệnh đề {@code NOT IN} với danh sách rỗng không hợp lệ trên mọi CSDL.
     */
    private List<Long> excludedAuthorIds(Long viewerId) {
        Set<Long> related = blockService.relatedUserIds(viewerId);
        return related.isEmpty() ? List.of(-1L) : List.copyOf(related);
    }

    /**
     * Video công khai đã duyệt thuộc một chủ đề, có thể lọc thêm JLPT.
     */
    private PageResponse<VideoResponse> getTopicFeed(Long currentUserId, Long topicId, JLPTLevel jlptLevel,
            Pageable pageable) {
        List<Long> excluded = excludedAuthorIds(currentUserId);
        Page<Video> page = jlptLevel != null
                ? videoRepository.findFeedByJlptLevelAndTopic(
                        VideoStatus.PUBLIC, VideoModStatus.APPROVED, jlptLevel, topicId, excluded, pageable)
                : videoRepository.findFeedByTopic(
                        VideoStatus.PUBLIC, VideoModStatus.APPROVED, topicId, excluded, pageable);
        return toVideoPageResponse(page, currentUserId);
    }

    /**
     * Tìm kiếm video công khai đã duyệt theo từ khoá (màn Khám phá).
     */
    private PageResponse<VideoResponse> searchVideos(Long currentUserId, String keyword, JLPTLevel jlptLevel,
            Pageable pageable) {
        List<Long> excluded = excludedAuthorIds(currentUserId);
        Page<Video> page = jlptLevel != null
                ? videoRepository.searchPublicVideosByJlptLevel(
                        VideoStatus.PUBLIC, VideoModStatus.APPROVED, jlptLevel, keyword, excluded, pageable)
                : videoRepository.searchPublicVideos(
                        VideoStatus.PUBLIC, VideoModStatus.APPROVED, keyword, excluded, pageable);
        return toVideoPageResponse(page, currentUserId);
    }

    /**
     * Dựng trang VideoResponse bằng vài truy vấn gộp (IN ...) cho CẢ trang thay vì
     * 4 truy vấn cho MỖI video (đã thích / đã lưu / đang theo dõi / đếm bình luận).
     * Feed 20 video: từ ~80 lượt gọi DB xuống còn 4.
     *
     * @param viewerId người đang xem; null thì bỏ qua trạng thái thích / lưu / theo dõi
     */
    private PageResponse<VideoResponse> toVideoPageResponse(Page<Video> page, Long viewerId) {
        List<Video> videos = page.getContent();
        List<Long> videoIds = videos.stream().map(Video::getId).toList();

        Map<Long, Long> commentCounts = videoIds.isEmpty()
                ? Map.of()
                : IdCount.toMap(videoCommentRepository.countByVideoIds(videoIds));
        Set<Long> likedIds = Set.of();
        Set<Long> savedIds = Set.of();
        Set<Long> followingIds = Set.of();
        if (viewerId != null && !videoIds.isEmpty()) {
            likedIds = videoLikeRepository.findLikedVideoIds(viewerId, videoIds);
            savedIds = videoSaveRepository.findSavedVideoIds(viewerId, videoIds);
            List<Long> creatorIds = videos.stream()
                    .map(v -> v.getUser().getId())
                    .distinct()
                    .toList();
            followingIds = followRepository.findFollowingIdsAmong(viewerId, creatorIds);
        }

        List<VideoResponse> responseList = new ArrayList<>(videos.size());
        for (Video v : videos) {
            VideoResponse response = videoMapper.toVideoResponse(v, likedIds.contains(v.getId()),
                    savedIds.contains(v.getId()), commentCounts.getOrDefault(v.getId(), 0L));
            response.setIsFollowing(response.getCreatorId() != null
                    && followingIds.contains(response.getCreatorId()));
            responseList.add(response);
        }

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
        return toVideoPageResponse(page, currentUserId);
    }

    /**
     * Lấy danh sách video của một Creator cụ thể.
     */
    @Override
    public PageResponse<VideoResponse> getVideosByUserId(Long userId, Long currentUserId, Pageable pageable) {
        Page<Video> page;

        // Hai người đã chặn nhau thì không xem được video của nhau.
        if (currentUserId != null && !currentUserId.equals(userId)
                && blockService.isBlockedEitherWay(currentUserId, userId)) {
            return toVideoPageResponse(Page.empty(pageable), currentUserId);
        }

        // Nếu người xem chính là chủ tài khoản -> xem được cả video Private/Unlisted
        if (currentUserId != null && currentUserId.equals(userId)) {
            page = videoRepository.findByUserId(userId, pageable);
        } else {
            page = videoRepository.findByUserIdAndStatus(userId, VideoStatus.PUBLIC, pageable);
        }
        return toVideoPageResponse(page, currentUserId);
    }

    @Override
    public PageResponse<VideoResponse> getLikedVideos(Long userId, Pageable pageable) {
        return toVideoPageResponse(videoRepository.findLikedByUserId(userId, pageable), userId);
    }

    @Override
    public PageResponse<VideoResponse> getSavedVideos(Long userId, Pageable pageable) {
        return toVideoPageResponse(videoRepository.findSavedByUserId(userId, pageable), userId);
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
            notificationService.notify(video.getUser().getId(), currentUserId, com.jlsp.backend.notification.entity.NotificationType.LIKE, videoId, null, null);
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
    public void incrementViewCount(Long videoId, String viewerKey) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        // Kiểm tra sau khi video tồn tại để id bừa không tạo khoá rác trong Redis.
        if (viewerKey != null
                && !rateLimiter.tryAcquire("view:" + videoId + ":" + viewerKey, 1, VIEW_DEDUP_WINDOW).allowed()) {
            return;
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
        // Subtitles đổi -> kết quả phân tích cũ không còn đúng, xoá và phân tích lại
        video.setGrammarAnalysis(null);
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
            String search, Long topicId, Pageable pageable) {
        if (userId != null) {
            return getVideosByUserId(userId, currentUserId, pageable);
        }
        if (search != null && !search.isBlank()) {
            return searchVideos(currentUserId, search.trim(), jlptLevel, pageable);
        }
        if ("following".equalsIgnoreCase(feed)) {
            return getFollowingFeed(currentUserId, pageable);
        }
        if ("recommended".equalsIgnoreCase(feed) && topicId == null && jlptLevel == null) {
            return getRecommendedFeed(currentUserId, pageable);
        }
        if (topicId != null) {
            return getTopicFeed(currentUserId, topicId, jlptLevel, pageable);
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
        // actor = null: kiểm duyệt viên ẩn danh với người đăng.
        notificationService.notify(video.getUser().getId(), null, com.jlsp.backend.notification.entity.NotificationType.VIDEO_APPROVED, videoId, null, null);
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
        notificationService.notify(video.getUser().getId(), null, com.jlsp.backend.notification.entity.NotificationType.VIDEO_REJECTED, videoId, null,
                video.getRejectionReason());
        return videoMapper.toVideoDetailResponse(saved, false, false);
    }

    @Override
    public PageResponse<VideoResponse> getModerationVideos(com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable) {
        com.jlsp.backend.video.entity.VideoModStatus targetStatus = modStatus != null ? modStatus : com.jlsp.backend.video.entity.VideoModStatus.PENDING;
        // Moderator CHỈ kiểm duyệt các video ở chế độ công khai (PUBLIC)
        Page<Video> page = videoRepository.findByStatusAndModStatus(VideoStatus.PUBLIC, targetStatus, pageable);
        return toVideoPageResponse(page, null);
    }

    @Override
    public PageResponse<VideoResponse> getMyVideosStatus(Long userId, Pageable pageable) {
        Page<Video> page = videoRepository.findByUserId(userId, pageable);
        return toVideoPageResponse(page, null);
    }
}
