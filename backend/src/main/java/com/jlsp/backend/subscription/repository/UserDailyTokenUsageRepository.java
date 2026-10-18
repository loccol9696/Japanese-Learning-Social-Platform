package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.common.projection.DailyTotal;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface UserDailyTokenUsageRepository extends JpaRepository<UserDailyTokenUsage, Long> {

    Optional<UserDailyTokenUsage> findByUserIdAndUsageDate(Long userId, LocalDate usageDate);

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(u.tokensUsed), 0) FROM UserDailyTokenUsage u")
    Long sumTotalTokensUsed();

    /** Tổng token đã dùng theo từng ngày trong [from, to] (usageDate đã là ngày). */
    @org.springframework.data.jpa.repository.Query("SELECT u.usageDate AS day, COALESCE(SUM(u.tokensUsed), 0) AS total " +
            "FROM UserDailyTokenUsage u WHERE u.usageDate BETWEEN :from AND :to GROUP BY u.usageDate")
    java.util.List<DailyTotal> sumTokensPerDay(
            @org.springframework.data.repository.query.Param("from") LocalDate from,
            @org.springframework.data.repository.query.Param("to") LocalDate to);

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(DISTINCT u.user.id) FROM UserDailyTokenUsage u WHERE u.tokensUsed > 0")
    long countDistinctActiveUsers();

    java.util.List<UserDailyTokenUsage> findByUsageDateBetween(LocalDate startDate, LocalDate endDate);
}
