package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.CommentLike;
import com.jlsp.backend.video.entity.CommentLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Set;

public interface CommentLikeRepository extends JpaRepository<CommentLike, CommentLikeId> {

    /**
     * Thêm lượt đánh giá nếu chưa có. Số dòng trả về quyết định có tăng like_count không, nên hai
     * request trùng nhau (nhấn đúp, gửi lại) chỉ được đếm một lần.
     *
     * @return 1 nếu vừa thêm, 0 nếu đã có từ trước
     */
    @Modifying
    @Query(value = "INSERT INTO comment_likes (user_id, comment_id, created_at) " +
            "VALUES (:userId, :commentId, :createdAt) ON CONFLICT DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("userId") Long userId, @Param("commentId") Long commentId,
                       @Param("createdAt") LocalDateTime createdAt);

    /**
     * @return 1 nếu vừa xóa, 0 nếu chưa từng đánh giá
     */
    @Modifying
    @Query("DELETE FROM CommentLike l WHERE l.id.userId = :userId AND l.id.commentId = :commentId")
    int deleteLike(@Param("userId") Long userId, @Param("commentId") Long commentId);

    /** Các bình luận của một video mà người dùng đã đánh giá. */
    @Query("SELECT l.id.commentId FROM CommentLike l WHERE l.id.userId = :userId AND l.comment.video.id = :videoId")
    Set<Long> findLikedCommentIds(@Param("userId") Long userId, @Param("videoId") Long videoId);
}
