package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CommentSort;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.CommentLikeResponse;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.CommentLikeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentServiceImpl implements CommentService {
    private final VideoCommentRepository commentRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final VideoRepository videoRepository;
    private final UserRepository userRepository;

    @Override
    public List<VideoCommentResponse> list(Long videoId, Long viewerId, CommentSort sort) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        // Phản hồi luôn xếp cũ đến mới để giữ mạch hội thoại; sort chỉ áp dụng cho bình luận gốc.
        Map<Long, List<VideoComment>> repliesByParent = commentRepository
                .findByVideoIdAndParentIsNotNullOrderByCreatedAtAsc(videoId).stream()
                .collect(Collectors.groupingBy(reply -> reply.getParent().getId()));
        Set<Long> likedIds = viewerId == null
                ? Set.of()
                : commentLikeRepository.findLikedCommentIds(viewerId, videoId);
        return commentRepository.findByVideoIdAndParentIsNull(videoId, sort.getOrder()).stream()
                .map(comment -> toResponse(comment, repliesByParent, likedIds))
                .toList();
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
        return toResponse(comment, Map.of(), Set.of());
    }

    @Override
    @Transactional
    public void delete(Long videoId, Long commentId, Long userId, boolean isAdmin) {
        VideoComment comment = findComment(videoId, commentId);
        if (!isAdmin && !comment.getUser().getId().equals(userId)) {
            throw new AppException(403, "Bạn chỉ có thể xóa bình luận của chính mình");
        }
        commentRepository.deleteByParentId(commentId);
        commentRepository.delete(comment);
    }

    @Override
    @Transactional
    public CommentLikeResponse like(Long videoId, Long commentId, Long userId) {
        VideoComment comment = findComment(videoId, commentId);
        if (comment.getUser().getId().equals(userId)) {
            throw new AppException(400, "Bạn không thể tự đánh giá bình luận của mình");
        }
        if (commentLikeRepository.insertIfAbsent(userId, commentId, LocalDateTime.now()) > 0) {
            commentRepository.updateLikeCount(commentId, 1);
        }
        return new CommentLikeResponse(true, commentRepository.findLikeCountById(commentId));
    }

    @Override
    @Transactional
    public CommentLikeResponse unlike(Long videoId, Long commentId, Long userId) {
        findComment(videoId, commentId);
        if (commentLikeRepository.deleteLike(userId, commentId) > 0) {
            commentRepository.updateLikeCount(commentId, -1);
        }
        return new CommentLikeResponse(false, commentRepository.findLikeCountById(commentId));
    }

    private VideoComment findComment(Long videoId, Long commentId) {
        VideoComment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new ResourceNotFoundException("Comment", "id", commentId));
        if (!comment.getVideo().getId().equals(videoId)) {
            throw new ResourceNotFoundException("Comment", "id", commentId);
        }
        return comment;
    }

    private VideoCommentResponse toResponse(VideoComment comment, Map<Long, List<VideoComment>> repliesByParent,
                                            Set<Long> likedIds) {
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
                .likeCount(comment.getLikeCount())
                .isLiked(likedIds.contains(comment.getId()))
                .createdAt(comment.getCreatedAt())
                .replies(comment.getParent() == null
                        ? repliesByParent.getOrDefault(comment.getId(), List.of()).stream()
                                .map(reply -> toResponse(reply, repliesByParent, likedIds)).toList()
                        : List.of())
                .build();
    }
}
