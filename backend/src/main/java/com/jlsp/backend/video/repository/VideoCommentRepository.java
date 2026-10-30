package com.jlsp.backend.video.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.video.entity.VideoComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface VideoCommentRepository extends JpaRepository<VideoComment, Long> {
    List<VideoComment> findByVideoIdAndParentIsNullOrderByCreatedAtDesc(Long videoId);
    List<VideoComment> findByParentIdOrderByCreatedAtAsc(Long parentId);
    long countByVideoId(Long videoId);
    void deleteByParentId(Long parentId);

    /** Số bình luận của nhiều video trong một truy vấn (video không có bình luận sẽ không có dòng). */
    @Query("SELECT c.video.id AS id, COUNT(c) AS total FROM VideoComment c " +
            "WHERE c.video.id IN :videoIds GROUP BY c.video.id")
    List<IdCount> countByVideoIds(@Param("videoIds") Collection<Long> videoIds);

    /** Như {@link #countByVideoIds} nhưng tính cả bình luận đã xóa mềm, dùng cho thùng rác. */
    @Query(value = "SELECT video_id AS id, COUNT(*) AS total FROM video_comments " +
            "WHERE video_id IN (:videoIds) GROUP BY video_id", nativeQuery = true)
    List<IdCount> countIncludingDeleted(@Param("videoIds") Collection<Long> videoIds);
}
