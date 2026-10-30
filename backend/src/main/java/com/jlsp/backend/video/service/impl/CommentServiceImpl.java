package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.notification.service.NotificationService;
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
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentServiceImpl implements CommentService {
    private final VideoCommentRepository commentRepository;
    private final VideoRepository videoRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    public List<VideoCommentResponse> list(Long videoId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        return commentRepository.findByVideoIdAndParentIsNullOrderByCreatedAtDesc(videoId)
                .stream().map(this::toResponse).toList();
    }

    @Override
    @Transactional
    public VideoCommentResponse create(Long videoId, Long userId, CreateCommentRequest request) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));
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
        eventPublisher.publishEvent(NotificationRequestedEvent.commented(
                video.getUser().getId(), userId, videoId, comment.getId(), comment.getContent()));
        return toResponse(comment);
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
        List<Long> removedIds = new ArrayList<>();
        removedIds.add(commentId);
        commentRepository.findByParentIdOrderByCreatedAtAsc(commentId).forEach(reply -> removedIds.add(reply.getId()));
        commentRepository.deleteByParentId(commentId);
        commentRepository.delete(comment);
        notificationService.deleteByComments(removedIds);
    }

    private VideoCommentResponse toResponse(VideoComment comment) {
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
                        ? commentRepository.findByParentIdOrderByCreatedAtAsc(comment.getId())
                                .stream().map(this::toResponse).toList()
                        : List.of())
                .build();
    }
}
