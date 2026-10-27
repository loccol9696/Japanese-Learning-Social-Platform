package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentServiceImpl implements CommentService {
    private final VideoCommentRepository commentRepository;
    private final VideoRepository videoRepository;
    private final UserRepository userRepository;
    private final com.jlsp.backend.block.service.BlockService blockService;
    private final com.jlsp.backend.notification.service.NotificationService notificationService;

    @Override
    public List<VideoCommentResponse> list(Long videoId, Long viewerId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        Set<Long> hidden = blockService.relatedUserIds(viewerId);
        // Hai truy vấn cho cả video (gốc và phản hồi), ghép lại trong bộ nhớ.
        Map<Long, List<VideoComment>> repliesByParent = commentRepository
                .findByVideoIdAndParentIsNotNullOrderByCreatedAtAsc(videoId).stream()
                .collect(Collectors.groupingBy(r -> r.getParent().getId()));
        return commentRepository.findByVideoIdAndParentIsNullOrderByCreatedAtDesc(videoId)
                .stream()
                .filter(c -> !hidden.contains(c.getUser().getId()))
                .map(c -> toResponse(c, hidden, repliesByParent))
                .toList();
    }

    @Override
    @Transactional
    public VideoCommentResponse create(Long videoId, Long userId, CreateCommentRequest request) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));
        if (blockService.isBlockedEitherWay(userId, video.getUser().getId())) {
            throw new AppException(403, "Bạn không thể bình luận trên video này");
        }
        VideoComment parent = null;
        if (request.getParentId() != null) {
            parent = commentRepository.findById(request.getParentId())
                    .orElseThrow(() -> new ResourceNotFoundException("Comment", "id", request.getParentId()));
            if (!parent.getVideo().getId().equals(videoId)) {
                throw new IllegalArgumentException("Bình luận trả lời phải thuộc cùng video");
            }
        }
        VideoComment comment = commentRepository.save(VideoComment.builder()
                .video(video).user(user).parent(parent).content(request.getContent().trim()).build());

        Long videoOwnerId = video.getUser().getId();
        if (parent != null) {
            Long parentAuthorId = parent.getUser().getId();
            notificationService.notify(parentAuthorId, userId, com.jlsp.backend.notification.entity.NotificationType.REPLY, videoId, comment.getId(), comment.getContent());
            // Chủ video cũng được báo (nếu khác người được trả lời), tránh gửi hai thông báo cho cùng một người.
            if (!videoOwnerId.equals(parentAuthorId)) {
                notificationService.notify(videoOwnerId, userId, com.jlsp.backend.notification.entity.NotificationType.COMMENT, videoId, comment.getId(), comment.getContent());
            }
        } else {
            notificationService.notify(videoOwnerId, userId, com.jlsp.backend.notification.entity.NotificationType.COMMENT, videoId, comment.getId(), comment.getContent());
        }
        return toResponse(comment, Set.of(), Map.of());
    }

    @Override
    @Transactional
    public void delete(Long videoId, Long commentId, Long userId, boolean isAdmin) {
        VideoComment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new ResourceNotFoundException("Comment", "id", commentId));
        if (!comment.getVideo().getId().equals(videoId)) {
            throw new ResourceNotFoundException("Comment", "id", commentId);
        }
        if (!isAdmin && !comment.getUser().getId().equals(userId)) {
            throw new AppException(403, "Bạn chỉ có thể xóa bình luận của chính mình");
        }
        commentRepository.deleteByParentId(commentId);
        commentRepository.delete(comment);
    }

    private VideoCommentResponse toResponse(VideoComment comment, Set<Long> hidden,
                                            Map<Long, List<VideoComment>> repliesByParent) {
        User user = comment.getUser();
        return VideoCommentResponse.builder()
                .id(comment.getId())
                .videoId(comment.getVideo().getId())
                .parentId(comment.getParent() == null ? null : comment.getParent().getId())
                .userId(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .content(comment.getContent())
                .createdAt(comment.getCreatedAt())
                .replies(comment.getParent() == null
                        ? repliesByParent.getOrDefault(comment.getId(), List.of())
                                .stream()
                                .filter(r -> !hidden.contains(r.getUser().getId()))
                                .map(r -> toResponse(r, hidden, repliesByParent))
                                .toList()
                        : List.of())
                .build();
    }
}
