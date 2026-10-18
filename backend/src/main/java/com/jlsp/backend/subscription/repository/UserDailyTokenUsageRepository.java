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
}
