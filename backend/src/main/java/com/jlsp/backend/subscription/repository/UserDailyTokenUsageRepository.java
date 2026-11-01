package com.jlsp.backend.subscription.repository;

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

    java.util.List<UserDailyTokenUsage> findByUsageDateBetween(LocalDate startDate, LocalDate endDate);

    /** Tổng token mỗi ngày trong [from, to) — gộp ở DB cho thống kê quản trị. */
    @org.springframework.data.jpa.repository.Query("SELECT year(u.usageDate) AS yr, month(u.usageDate) AS mo, " +
            "day(u.usageDate) AS dy, SUM(u.tokensUsed) AS total FROM UserDailyTokenUsage u " +
            "WHERE u.usageDate >= :from AND u.usageDate < :to " +
            "GROUP BY year(u.usageDate), month(u.usageDate), day(u.usageDate)")
    java.util.List<com.jlsp.backend.admin.dto.DayTotal> sumTokensByDay(
            @org.springframework.data.repository.query.Param("from") LocalDate from,
            @org.springframework.data.repository.query.Param("to") LocalDate to);

    /** Số người đã dùng token ít nhất một lần. */
    @org.springframework.data.jpa.repository.Query(
            "SELECT COUNT(DISTINCT u.user.id) FROM UserDailyTokenUsage u WHERE u.tokensUsed > 0")
    long countUsersWithUsage();
}
