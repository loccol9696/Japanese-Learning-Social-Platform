package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoComment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VideoCommentRepository extends JpaRepository<VideoComment, Long> {
    List<VideoComment> findByVideoIdAndParentIsNullOrderByCreatedAtDesc(Long videoId);
    List<VideoComment> findByParentIdOrderByCreatedAtAsc(Long parentId);
    long countByVideoId(Long videoId);
    void deleteByParentId(Long parentId);
}
