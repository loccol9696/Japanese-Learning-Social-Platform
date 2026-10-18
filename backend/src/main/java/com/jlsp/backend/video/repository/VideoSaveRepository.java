package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.VideoSave;
import com.jlsp.backend.video.entity.VideoSaveId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

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
     * Đếm tổng số lượt lưu của một video.
     */
    long countByIdVideoId(Long videoId);
}
