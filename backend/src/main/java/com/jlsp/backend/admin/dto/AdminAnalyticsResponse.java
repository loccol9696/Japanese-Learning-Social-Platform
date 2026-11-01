package com.jlsp.backend.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminAnalyticsResponse {

    // 1. User Registration Analytics
    private long totalUsers;
    private long activeUsers;
    private long lockedUsers;
    private long adminCount;
    private long moderatorCount;
    private long learnerCount;
    private List<DailyMetricDto> userRegistrationTrends;

    // 2. Token Usage Analytics
    private long totalTokensUsed;
    private long activeTokenUsersCount;
    private List<DailyMetricDto> tokenUsageTrends;

    // 3. Subscription Revenue Analytics
    private long totalRevenue;
    private long successfulOrdersCount;
    private long pendingOrdersCount;
    private List<DailyMetricDto> revenueTrends;
    private List<PlanSalesBreakdownDto> planSalesBreakdown;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DailyMetricDto {
        private String dateLabel; // e.g. "12/10"
        private long value;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlanSalesBreakdownDto {
        private String planCode;
        private String planName;
        private long salesCount;
        private long revenue;
        private double percentage;
    }
}
