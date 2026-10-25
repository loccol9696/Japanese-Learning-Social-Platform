package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoSave;
import com.jlsp.backend.video.entity.VideoSaveId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.Set;

/**
 * Repository thao tác với bảng 'video_saves'.
 */
@Repository
public interface VideoSaveRepository extends JpaRepository<VideoSave, VideoSaveId> {

    /**
     * Kiểm tra xem người dùng userId đã lưu video videoId vào bộ sưu tập hay chưa.
     */
    boolean existsByIdUserIdAndIdVideoId(Long userId, Long videoId);

    /**
     * Trong số videoIds, những video người dùng đã lưu — một truy vấn cho cả trang feed.
     */
    @Query("SELECT s.id.videoId FROM VideoSave s WHERE s.id.userId = :userId AND s.id.videoId IN :videoIds")
    Set<Long> findSavedVideoIds(@Param("userId") Long userId, @Param("videoIds") Collection<Long> videoIds);

    /**
     * Đếm tổng số lượt lưu của một video.
     */
    long countByIdVideoId(Long videoId);
}
