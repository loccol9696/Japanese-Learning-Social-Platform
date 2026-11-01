package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.TokenFeature;
import com.jlsp.backend.subscription.entity.TokenUsageEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface TokenUsageEventRepository extends JpaRepository<TokenUsageEvent, Long> {

    /** Tổng token của một người theo từng ngày trong [from, to] (ngày không dùng thì không có dòng). */
    @Query("SELECT e.usageDate AS usageDay, SUM(e.tokens) AS total FROM TokenUsageEvent e " +
            "WHERE e.user.id = :userId AND e.usageDate BETWEEN :from AND :to GROUP BY e.usageDate")
    List<DayTotal> sumByDay(@Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Tổng token của một người theo từng tính năng trong [from, to]. */
    @Query("SELECT e.feature AS feature, SUM(e.tokens) AS total FROM TokenUsageEvent e " +
            "WHERE e.user.id = :userId AND e.usageDate BETWEEN :from AND :to GROUP BY e.feature")
    List<FeatureTotal> sumByFeature(@Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    interface DayTotal {
        LocalDate getUsageDay();

        Long getTotal();
    }

    interface FeatureTotal {
        TokenFeature getFeature();

        Long getTotal();
    }
}
