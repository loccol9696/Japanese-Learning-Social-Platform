package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoLike;
import com.jlsp.backend.video.entity.VideoLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.Set;

/**
 * Repository thao tác với bảng 'video_likes'.
 */
@Repository
public interface VideoLikeRepository extends JpaRepository<VideoLike, VideoLikeId> {

    /**
     * Kiểm tra xem người dùng userId đã thích video videoId hay chưa.
     */
    boolean existsByIdUserIdAndIdVideoId(Long userId, Long videoId);

    /**
     * Trong số videoIds, những video người dùng đã thích — một truy vấn cho cả trang feed.
     */
    @Query("SELECT l.id.videoId FROM VideoLike l WHERE l.id.userId = :userId AND l.id.videoId IN :videoIds")
    Set<Long> findLikedVideoIds(@Param("userId") Long userId, @Param("videoIds") Collection<Long> videoIds);

    /**
     * Đếm tổng số lượt thích của một video.
     */
    long countByIdVideoId(Long videoId);
}
