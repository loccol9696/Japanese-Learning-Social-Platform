package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.event.VideoPurgedEvent;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoTrashStore;
import com.jlsp.backend.video.service.VideoTrashService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class VideoTrashServiceImpl implements VideoTrashService {

    private static final int PURGE_BATCH_SIZE = 500;

    private final VideoRepository videoRepository;
    private final VideoCommentRepository videoCommentRepository;
    private final VideoTrashStore trashStore;
    private final UserRepository userRepository;
    private final VideoMapper videoMapper;
    private final ApplicationEventPublisher eventPublisher;

    @Value("${app.video.trash-retention-days:30}")
    private int retentionDays;

    @Override
    @Transactional
    public void moveToTrash(Long videoId, Long currentUserId) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        requireOwnerOrAdmin(video, currentUserId);

        trashStore.softDelete(videoId, LocalDateTime.now());
        log.info("User ID: {} đã chuyển video ID: {} vào thùng rác", currentUserId, videoId);
    }

    @Override
    public PageResponse<VideoResponse> listTrash(Long userId, Pageable pageable) {
        // Truy vấn đã tự sắp theo thời điểm xóa; bỏ sort của client vì SQL thuần không nhận tên thuộc tính.
        Page<Video> page = videoRepository.findTrashByUserId(userId, retentionCutoff(),
                PageRequest.of(pageable.getPageNumber(), pageable.getPageSize()));

        List<Long> videoIds = page.getContent().stream().map(Video::getId).toList();
        Map<Long, Long> commentCounts = videoIds.isEmpty()
                ? Map.of()
                : IdCount.toMap(videoCommentRepository.countIncludingDeleted(videoIds));

        return PageResponse.from(page.map(video -> {
            VideoResponse response = videoMapper.toVideoResponse(video, false, false,
                    commentCounts.getOrDefault(video.getId(), 0L));
            response.setDeletedAt(video.getDeletedAt());
            response.setPurgeAt(video.getDeletedAt().plusDays(retentionDays));
            return response;
        }));
    }

    @Override
    @Transactional
    public void restore(Long videoId, Long currentUserId) {
        Video video = findInTrash(videoId);
        requireOwnerOrAdmin(video, currentUserId);

        trashStore.restore(videoId);
        log.info("User ID: {} đã khôi phục video ID: {}", currentUserId, videoId);
    }

    @Override
    @Transactional
    public void deletePermanently(Long videoId, Long currentUserId) {
        Video video = findInTrash(videoId);
        requireOwnerOrAdmin(video, currentUserId);

        purge(video);
        log.info("User ID: {} đã xóa hẳn video ID: {}", currentUserId, videoId);
    }

    @Override
    public List<Long> findExpiredIds() {
        return videoRepository.findExpiredTrashIds(retentionCutoff(), PURGE_BATCH_SIZE);
    }

    @Override
    @Transactional
    public void purgeExpired(Long videoId) {
        videoRepository.findDeletedById(videoId)
                .filter(this::isExpired)
                .ifPresent(this::purge);
    }

    private void purge(Video video) {
        trashStore.hardDelete(video.getId());
        // File trên cloud chỉ gỡ sau khi DB đã commit: rollback thì video vẫn còn file để phát.
        eventPublisher.publishEvent(new VideoPurgedEvent(
                unusedMedia(video.getVideoUrl()), unusedMedia(video.getThumbnailUrl())));
    }

    private String unusedMedia(String url) {
        return url == null || trashStore.isMediaInUse(url) ? null : url;
    }

    /** Video quá hạn coi như đã mất dù job dọn dẹp chưa chạy tới. */
    private Video findInTrash(Long videoId) {
        return videoRepository.findDeletedById(videoId)
                .filter(video -> !isExpired(video))
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
    }

    private boolean isExpired(Video video) {
        return video.getDeletedAt().isBefore(retentionCutoff());
    }

    private LocalDateTime retentionCutoff() {
        return LocalDateTime.now().minusDays(retentionDays);
    }

    private void requireOwnerOrAdmin(Video video, Long currentUserId) {
        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", currentUserId));
        if (!video.getUser().getId().equals(currentUserId) && user.getRole() != UserRole.ADMIN) {
            throw new AppException(403, "Bạn không có quyền thao tác trên video này");
        }
    }
}
