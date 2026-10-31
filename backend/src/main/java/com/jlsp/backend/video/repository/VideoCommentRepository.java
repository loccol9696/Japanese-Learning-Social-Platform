package com.jlsp.backend.video.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.video.entity.VideoComment;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface VideoCommentRepository extends JpaRepository<VideoComment, Long> {
    /** Bình luận gốc của video, kèm người viết trong cùng truy vấn. */
    @EntityGraph(attributePaths = "user")
    List<VideoComment> findByVideoIdAndParentIsNull(Long videoId, Sort sort);

    /** Toàn bộ phản hồi của video trong một truy vấn (thay vì mỗi bình luận gốc một truy vấn). */
    @EntityGraph(attributePaths = {"user", "parent", "replyTo", "replyTo.user"})
    List<VideoComment> findByVideoIdAndParentIsNotNullOrderByCreatedAtAsc(Long videoId);

    long countByVideoId(Long videoId);
    List<VideoComment> findByParentId(Long parentId);
    void deleteByParentId(Long parentId);

    /** Cập nhật like_count tăng (+1) hoặc giảm (-1), đảm bảo không âm. */
    @Modifying
    @Query("UPDATE VideoComment c SET c.likeCount = CASE WHEN (c.likeCount + :amount) < 0 THEN 0 " +
            "ELSE (c.likeCount + :amount) END WHERE c.id = :id")
    void updateLikeCount(@Param("id") Long id, @Param("amount") int amount);

    /** Đọc thẳng từ DB vì {@link #updateLikeCount} không cập nhật entity đã nạp. */
    @Query("SELECT c.likeCount FROM VideoComment c WHERE c.id = :id")
    int findLikeCountById(@Param("id") Long id);

    /** Gỡ liên kết "trả lời" tới các bình luận sắp xoá, để khoá ngoại không chặn việc xoá. */
    @Modifying
    @Query("UPDATE VideoComment c SET c.replyTo = null WHERE c.replyTo.id IN :ids")
    void clearReplyTo(@Param("ids") Collection<Long> ids);

    /** Số bình luận của nhiều video trong một truy vấn (video không có bình luận sẽ không có dòng). */
    @Query("SELECT c.video.id AS id, COUNT(c) AS total FROM VideoComment c " +
            "WHERE c.video.id IN :videoIds GROUP BY c.video.id")
    List<IdCount> countByVideoIds(@Param("videoIds") Collection<Long> videoIds);

    /** Như {@link #countByVideoIds} nhưng tính cả bình luận đã xóa mềm, dùng cho thùng rác. */
    @Query(value = "SELECT video_id AS id, COUNT(*) AS total FROM video_comments " +
            "WHERE video_id IN (:videoIds) GROUP BY video_id", nativeQuery = true)
    List<IdCount> countIncludingDeleted(@Param("videoIds") Collection<Long> videoIds);
}
