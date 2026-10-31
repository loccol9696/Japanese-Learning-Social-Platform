package com.jlsp.backend.video.repository;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
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
    @EntityGraph(attributePaths = "user")
    Page<Video> findByStatus(VideoStatus status, Pageable pageable);

    long countByStatus(VideoStatus status);

    /**
     * Lưu kết quả phân tích ngữ pháp, CHỈ KHI subtitles vẫn là bản đã được phân tích.
     * Nếu user đã sửa subtitles trong lúc AI chạy -> không cập nhật (trả về 0),
     * job mới (do lần sửa đó kích hoạt) sẽ ghi kết quả đúng.
     */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE Video v SET v.grammarAnalysis = :analysis WHERE v.id = :id AND v.subtitles = :subtitles")
    int updateGrammarAnalysisIfSubtitlesUnchanged(@Param("id") Long id,
                                                  @Param("subtitles") String subtitles,
                                                  @Param("analysis") String analysis);

    Page<Video> findByModStatus(com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable);

    long countByModStatus(com.jlsp.backend.video.entity.VideoModStatus modStatus);

    @EntityGraph(attributePaths = "user")
    Page<Video> findByStatusAndModStatus(VideoStatus status, com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable);

    long countByStatusAndModStatus(VideoStatus status, com.jlsp.backend.video.entity.VideoModStatus modStatus);

    /**
     * Feed công khai đã duyệt, loại trừ video của những người có quan hệ chặn với người xem.
     * {@code excluded} không được rỗng (truyền một id không tồn tại như -1 khi không có ai bị loại).
     */
    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.user.id NOT IN :excluded")
    Page<Video> findFeed(@Param("status") VideoStatus status,
                         @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                         @Param("excluded") java.util.Collection<Long> excluded,
                         Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.jlptLevel = :jlptLevel AND v.user.id NOT IN :excluded")
    Page<Video> findFeedByJlptLevel(@Param("status") VideoStatus status,
                                    @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                                    @Param("jlptLevel") JLPTLevel jlptLevel,
                                    @Param("excluded") java.util.Collection<Long> excluded,
                                    Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.topic.id = :topicId AND v.user.id NOT IN :excluded")
    Page<Video> findFeedByTopic(@Param("status") VideoStatus status,
                                @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                                @Param("topicId") Long topicId,
                                @Param("excluded") java.util.Collection<Long> excluded,
                                Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.jlptLevel = :jlptLevel AND v.topic.id = :topicId AND v.user.id NOT IN :excluded")
    Page<Video> findFeedByJlptLevelAndTopic(@Param("status") VideoStatus status,
                                            @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                                            @Param("jlptLevel") JLPTLevel jlptLevel,
                                            @Param("topicId") Long topicId,
                                            @Param("excluded") java.util.Collection<Long> excluded,
                                            Pageable pageable);

    /**
     * Tìm video công khai đã duyệt theo tiêu đề / mô tả (màn Khám phá), có thể lọc thêm JLPT.
     */
    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.user.id NOT IN :excluded " +
           "AND (LOWER(v.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(COALESCE(v.description, '')) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    Page<Video> searchPublicVideos(@Param("status") VideoStatus status,
                                   @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                                   @Param("keyword") String keyword,
                                   @Param("excluded") java.util.Collection<Long> excluded,
                                   Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v WHERE v.status = :status AND v.modStatus = :modStatus " +
           "AND v.jlptLevel = :jlptLevel AND v.user.id NOT IN :excluded " +
           "AND (LOWER(v.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(COALESCE(v.description, '')) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    Page<Video> searchPublicVideosByJlptLevel(@Param("status") VideoStatus status,
                                              @Param("modStatus") com.jlsp.backend.video.entity.VideoModStatus modStatus,
                                              @Param("jlptLevel") JLPTLevel jlptLevel,
                                              @Param("keyword") String keyword,
                                              @Param("excluded") java.util.Collection<Long> excluded,
                                              Pageable pageable);

    @EntityGraph(attributePaths = "user")
    Page<Video> findByUserIdInAndStatusAndModStatus(List<Long> userIds, VideoStatus status, com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable);

    /**
     * Lấy danh sách video công khai theo cấp độ JLPT chỉ định (Dành cho Feed đề xuất theo trình độ).
     */
    @EntityGraph(attributePaths = "user")
    Page<Video> findByStatusAndJlptLevel(VideoStatus status, JLPTLevel jlptLevel, Pageable pageable);

    /**
     * Lấy danh sách video của một Creator cụ thể có trạng thái chỉ định.
     */
    @EntityGraph(attributePaths = "user")
    Page<Video> findByUserIdAndStatus(Long userId, VideoStatus status, Pageable pageable);

    /**
     * Lấy danh sách video của người dùng (dành cho chính chủ xem cả video private/public).
     */
    @EntityGraph(attributePaths = "user")
    Page<Video> findByUserId(Long userId, Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v JOIN VideoLike l ON l.id.videoId = v.id WHERE l.id.userId = :userId ORDER BY v.createdAt DESC")
    Page<Video> findLikedByUserId(@Param("userId") Long userId, Pageable pageable);

    @EntityGraph(attributePaths = "user")
    @Query("SELECT v FROM Video v JOIN VideoSave s ON s.id.videoId = v.id WHERE s.id.userId = :userId ORDER BY v.createdAt DESC")
    Page<Video> findSavedByUserId(@Param("userId") Long userId, Pageable pageable);

    /**
     * Lấy danh sách video từ danh sách ID các Creator mà user đang theo dõi (Following Feed).
     */
    @EntityGraph(attributePaths = "user")
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

    /**
     * Tổng số video của một user
     */
    long countByUserId(Long userId);

    /**
     * Tổng số lượt thích trên tất cả video của một user
     */
    @Query("SELECT COALESCE(SUM(v.likeCount), 0) FROM Video v WHERE v.user.id = :userId")
    long sumLikesByUserId(@Param("userId") Long userId);
}
