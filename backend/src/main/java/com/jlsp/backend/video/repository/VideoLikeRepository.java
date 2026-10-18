package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoLike;
import com.jlsp.backend.video.entity.VideoLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

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
     * Đếm tổng số lượt thích của một video.
     */
    long countByIdVideoId(Long videoId);
}
