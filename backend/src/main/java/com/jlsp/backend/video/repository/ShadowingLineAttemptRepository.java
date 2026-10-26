package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.ShadowingLineAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ShadowingLineAttemptRepository extends JpaRepository<ShadowingLineAttempt, Long> {

    /** Mỗi hàng: [lineIndex, điểm cao nhất, số lần thử]. */
    @Query("SELECT a.lineIndex, MAX(a.score), COUNT(a) FROM ShadowingLineAttempt a "
            + "WHERE a.user.id = :userId AND a.video.id = :videoId GROUP BY a.lineIndex ORDER BY a.lineIndex")
    List<Object[]> summarize(@Param("userId") Long userId, @Param("videoId") Long videoId);
}
