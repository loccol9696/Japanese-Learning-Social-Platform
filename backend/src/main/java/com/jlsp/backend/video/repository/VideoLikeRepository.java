package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoLike;
import com.jlsp.backend.video.entity.VideoLikeId;
import com.jlsp.backend.video.entity.Video;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

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

    /**
     * Video người dùng đã thích, mới nhất trước. Bỏ qua video đã bị ẩn/từ chối
     * (trừ khi là video của chính người dùng).
     */
    @Query(value = "SELECT v FROM VideoLike x JOIN x.video v WHERE x.id.userId = :userId AND (v.user.id = :userId OR (v.status = com.jlsp.backend.video.entity.VideoStatus.PUBLIC AND v.modStatus = com.jlsp.backend.video.entity.VideoModStatus.APPROVED)) ORDER BY x.createdAt DESC",
            countQuery = "SELECT COUNT(x) FROM VideoLike x JOIN x.video v WHERE x.id.userId = :userId AND (v.user.id = :userId OR (v.status = com.jlsp.backend.video.entity.VideoStatus.PUBLIC AND v.modStatus = com.jlsp.backend.video.entity.VideoModStatus.APPROVED))")
    Page<Video> findVideosByUserId(@Param("userId") Long userId, Pageable pageable);

    /**
     * Trong các video [videoIds], những video người dùng đã thích (tránh N+1 khi map danh sách).
     */
    @Query("SELECT x.id.videoId FROM VideoLike x WHERE x.id.userId = :userId AND x.id.videoId IN :videoIds")
    List<Long> findVideoIdsByUserIdAndVideoIdIn(@Param("userId") Long userId, @Param("videoIds") Collection<Long> videoIds);
}
