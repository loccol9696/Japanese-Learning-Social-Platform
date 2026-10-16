package com.jlsp.backend.video.repository;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Repository thao tác với bảng 'videos'.
 */
@Repository
public interface VideoRepository extends JpaRepository<Video, Long> {

    /**
     * Lấy danh sách video công khai theo phân trang (Dành cho Feed tổng quan).
     */
    Page<Video> findByStatus(VideoStatus status, Pageable pageable);

    /**
     * Lấy danh sách video công khai theo cấp độ JLPT chỉ định (Dành cho Feed đề xuất theo trình độ).
     */
    Page<Video> findByStatusAndJlptLevel(VideoStatus status, JLPTLevel jlptLevel, Pageable pageable);

    /**
     * Lấy danh sách video của một Creator cụ thể có trạng thái chỉ định.
     */
    Page<Video> findByUserIdAndStatus(Long userId, VideoStatus status, Pageable pageable);

    /**
     * Lấy danh sách video của người dùng (dành cho chính chủ xem cả video private/public).
     */
    Page<Video> findByUserId(Long userId, Pageable pageable);

    /**
     * Lấy danh sách video từ danh sách ID các Creator mà user đang theo dõi (Following Feed).
     */
    Page<Video> findByUserIdInAndStatus(List<Long> userIds, VideoStatus status, Pageable pageable);

    /**
     * Tăng số lượt xem (view_count) một cách an toàn và nguyên tử (Atomic Update).
     */
    @Modifying
    @Query("UPDATE Video v SET v.viewCount = v.viewCount + 1 WHERE v.id = :id")
    void incrementViewCount(@Param("id") Long id);

    /**
     * Cập nhật số lượt thích (like_count) tăng (+1) hoặc giảm (-1), đảm bảo không âm.
     */
    @Modifying
    @Query("UPDATE Video v SET v.likeCount = CASE WHEN (v.likeCount + :amount) < 0 THEN 0 ELSE (v.likeCount + :amount) END WHERE v.id = :id")
    void updateLikeCount(@Param("id") Long id, @Param("amount") int amount);

    /**
     * Cập nhật số lượt lưu (save_count) tăng (+1) hoặc giảm (-1), đảm bảo không âm.
     */
    @Modifying
    @Query("UPDATE Video v SET v.saveCount = CASE WHEN (v.saveCount + :amount) < 0 THEN 0 ELSE (v.saveCount + :amount) END WHERE v.id = :id")
    void updateSaveCount(@Param("id") Long id, @Param("amount") int amount);
}
