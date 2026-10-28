package com.jlsp.backend.video.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.video.entity.VideoComment;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface VideoCommentRepository extends JpaRepository<VideoComment, Long> {
    /** Bình luận gốc của video, kèm người viết trong cùng truy vấn. */
    @EntityGraph(attributePaths = "user")
    List<VideoComment> findByVideoIdAndParentIsNullOrderByCreatedAtDesc(Long videoId);

    /** Toàn bộ phản hồi của video trong MỘT truy vấn (thay vì mỗi bình luận gốc một truy vấn). */
    @EntityGraph(attributePaths = {"user", "parent"})
    List<VideoComment> findByVideoIdAndParentIsNotNullOrderByCreatedAtAsc(Long videoId);
    long countByVideoId(Long videoId);
    void deleteByParentId(Long parentId);

    /** Số bình luận của nhiều video trong một truy vấn (video không có bình luận sẽ không có dòng). */
    @Query("SELECT c.video.id AS id, COUNT(c) AS total FROM VideoComment c " +
            "WHERE c.video.id IN :videoIds GROUP BY c.video.id")
    List<IdCount> countByVideoIds(@Param("videoIds") Collection<Long> videoIds);
}
