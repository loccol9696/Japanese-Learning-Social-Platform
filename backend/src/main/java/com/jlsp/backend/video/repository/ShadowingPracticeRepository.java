package com.jlsp.backend.video.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.video.entity.ShadowingPractice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
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

    /**
     * Số học viên khác nhau đã luyện shadowing của từng video, trong một truy vấn (video chưa ai luyện sẽ
     * không có dòng). Đếm theo người để một người nộp nhiều lần không làm tăng điểm.
     */
    @Query("SELECT p.video.id AS id, COUNT(DISTINCT p.user.id) AS total FROM ShadowingPractice p " +
            "WHERE p.video.id IN :videoIds GROUP BY p.video.id")
    List<IdCount> countPractitionersByVideoIds(@Param("videoIds") Collection<Long> videoIds);
}
