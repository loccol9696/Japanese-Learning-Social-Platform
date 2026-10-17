package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.ShadowingPractice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Repository thao tác với bảng 'shadowing_practice'.
 */
@Repository
public interface ShadowingPracticeRepository extends JpaRepository<ShadowingPractice, Long> {

    /**
     * Lấy danh sách lịch sử nộp bài luyện nói Shadowing của một học viên cho một video cụ thể,
     * sắp xếp theo thời gian mới nhất trước.
     */
    List<ShadowingPractice> findByVideoIdAndUserIdOrderByCreatedAtDesc(Long videoId, Long userId);

    /**
     * Lấy toàn bộ lịch sử luyện nói của một học viên có phân trang.
     */
    Page<ShadowingPractice> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
}
