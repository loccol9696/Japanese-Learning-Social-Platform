package com.jlsp.backend.admin.controller;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.PlanSalesBreakdownDto;
import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/v1/admin/analytics")
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminAnalyticsController {

    private final UserRepository userRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final SubscriptionOrderRepository orderRepository;
    private final SubscriptionPlanRepository planRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<AdminAnalyticsResponse>> getAnalytics(
            @RequestParam(value = "period", defaultValue = "7days") String period) {
        log.info("Fetching admin platform analytics with period: {}", period);

        // 1. User metrics: CHỈ TÍNH HỌC VIÊN / NGƯỜI DÙNG THẬT (USER), KHÔNG TÍNH ADMIN / MODERATOR
        long totalUsers = userRepository.countByRole(UserRole.USER);
        long activeUsers = userRepository.countByRoleAndIsActive(UserRole.USER, true);
        long lockedUsers = userRepository.countByRoleAndIsActive(UserRole.USER, false);
        long adminCount = userRepository.countByRole(UserRole.ADMIN);
        long moderatorCount = userRepository.countByRole(UserRole.MODERATOR);
        long learnerCount = totalUsers;

        LocalDate today = LocalDate.now();
        int currentYear = today.getYear();

        List<User> allUsers = userRepository.findAll();
        List<UserDailyTokenUsage> tokenUsages = tokenUsageRepository.findAll();
        List<SubscriptionOrder> successOrders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
        List<SubscriptionOrder> pendingOrders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.PENDING);

        List<DailyMetricDto> userRegistrationTrends = new ArrayList<>();
        List<DailyMetricDto> tokenUsageTrends = new ArrayList<>();
        List<DailyMetricDto> revenueTrends = new ArrayList<>();

        if ("year".equalsIgnoreCase(period)) {
            // Theo năm: 5 năm gần nhất (e.g. 2022 -> 2026)
            int startYear = currentYear - 4;
            Map<Integer, Long> userYearMap = allUsers.stream()
                    .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                    .collect(Collectors.groupingBy(u -> u.getCreatedAt().getYear(), Collectors.counting()));

            Map<Integer, Long> tokenYearMap = tokenUsages.stream()
                    .filter(u -> u.getUsageDate() != null)
                    .collect(Collectors.groupingBy(
                            u -> u.getUsageDate().getYear(),
                            Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                    ));

            Map<Integer, Long> revenueYearMap = successOrders.stream()
                    .filter(o -> o.getCreatedAt() != null)
                    .collect(Collectors.groupingBy(
                            o -> o.getCreatedAt().getYear(),
                            Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                    ));

            for (int y = startYear; y <= currentYear; y++) {
                String label = String.valueOf(y);
                userRegistrationTrends.add(new DailyMetricDto(label, userYearMap.getOrDefault(y, 0L)));
                tokenUsageTrends.add(new DailyMetricDto(label, tokenYearMap.getOrDefault(y, 0L)));
                revenueTrends.add(new DailyMetricDto(label, revenueYearMap.getOrDefault(y, 0L)));
            }

        } else if ("month".equalsIgnoreCase(period)) {
            // Theo tháng: 12 tháng trong năm hiện tại
            Map<Integer, Long> userMonthMap = allUsers.stream()
                    .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null && u.getCreatedAt().getYear() == currentYear)
                    .collect(Collectors.groupingBy(u -> u.getCreatedAt().getMonthValue(), Collectors.counting()));

            Map<Integer, Long> tokenMonthMap = tokenUsages.stream()
                    .filter(u -> u.getUsageDate() != null && u.getUsageDate().getYear() == currentYear)
                    .collect(Collectors.groupingBy(
                            u -> u.getUsageDate().getMonthValue(),
                            Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                    ));

            Map<Integer, Long> revenueMonthMap = successOrders.stream()
                    .filter(o -> o.getCreatedAt() != null && o.getCreatedAt().getYear() == currentYear)
                    .collect(Collectors.groupingBy(
                            o -> o.getCreatedAt().getMonthValue(),
                            Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                    ));

            for (int m = 1; m <= 12; m++) {
                String label = String.format("Th%02d", m);
                userRegistrationTrends.add(new DailyMetricDto(label, userMonthMap.getOrDefault(m, 0L)));
                tokenUsageTrends.add(new DailyMetricDto(label, tokenMonthMap.getOrDefault(m, 0L)));
                revenueTrends.add(new DailyMetricDto(label, revenueMonthMap.getOrDefault(m, 0L)));
            }

        } else {
            // Mặc định: 7 ngày gần nhất
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");
            List<LocalDate> last7Days = new ArrayList<>();
            for (int i = 6; i >= 0; i--) {
                last7Days.add(today.minusDays(i));
            }

            Map<LocalDate, Long> userRegMap = allUsers.stream()
                    .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                    .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

            Map<LocalDate, Long> tokenTrendMap = tokenUsages.stream()
                    .filter(u -> u.getUsageDate() != null)
                    .collect(Collectors.groupingBy(
                            u -> u.getUsageDate(),
                            Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                    ));

            Map<LocalDate, Long> revenueTrendMap = successOrders.stream()
                    .filter(o -> o.getCreatedAt() != null)
                    .collect(Collectors.groupingBy(
                            o -> o.getCreatedAt().toLocalDate(),
                            Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                    ));

            for (LocalDate d : last7Days) {
                String label = d.format(fmt);
                userRegistrationTrends.add(new DailyMetricDto(label, userRegMap.getOrDefault(d, 0L)));
                tokenUsageTrends.add(new DailyMetricDto(label, tokenTrendMap.getOrDefault(d, 0L)));
                revenueTrends.add(new DailyMetricDto(label, revenueTrendMap.getOrDefault(d, 0L)));
            }
        }

        // 2. Token usage metrics: 100% dữ liệu thực từ bảng user_daily_token_usage
        Long totalTokensUsed = tokenUsageRepository.sumTotalTokensUsed();
        if (totalTokensUsed == null) totalTokensUsed = 0L;

        long activeTokenUsers = tokenUsages.stream()
                .filter(u -> u.getTokensUsed() != null && u.getTokensUsed() > 0)
                .map(u -> u.getUser() != null ? u.getUser().getId() : 0L)
                .filter(id -> id != 0L)
                .distinct()
                .count();

        // 3. Subscription Revenue metrics: 100% dữ liệu thực từ bảng subscription_orders
        java.math.BigDecimal totalRevBd = orderRepository.sumTotalAmountByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
        long totalRevenue = totalRevBd != null ? totalRevBd.longValue() : 0L;

        // Plan breakdown: Dữ liệu thực phân bổ theo các gói
        List<SubscriptionPlan> allPlans = planRepository.findAll();
        Map<String, List<SubscriptionOrder>> ordersByPlan = successOrders.stream()
                .filter(o -> o.getPlan() != null)
                .collect(Collectors.groupingBy(o -> o.getPlan().getCode()));

        long grandTotalRevenue = totalRevenue > 0 ? totalRevenue : 0;
        List<PlanSalesBreakdownDto> planBreakdown = allPlans.stream()
                .map(p -> {
                    List<SubscriptionOrder> pOrders = ordersByPlan.getOrDefault(p.getCode(), Collections.emptyList());
                    long sumRev = pOrders.stream().mapToLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L).sum();
                    double pct = grandTotalRevenue > 0 ? ((double) sumRev / grandTotalRevenue * 100.0) : 0.0;
                    return PlanSalesBreakdownDto.builder()
                            .planCode(p.getCode())
                            .planName(p.getName())
                            .salesCount(pOrders.size())
                            .revenue(sumRev)
                            .percentage(Math.round(pct * 10.0) / 10.0)
                            .build();
                })
                .collect(Collectors.toList());

        AdminAnalyticsResponse response = AdminAnalyticsResponse.builder()
                .totalUsers(totalUsers)
                .activeUsers(activeUsers)
                .lockedUsers(lockedUsers)
                .adminCount(adminCount)
                .moderatorCount(moderatorCount)
                .learnerCount(learnerCount)
                .userRegistrationTrends(userRegistrationTrends)
                .totalTokensUsed(totalTokensUsed)
                .activeTokenUsersCount(activeTokenUsers)
                .tokenUsageTrends(tokenUsageTrends)
                .totalRevenue(totalRevenue)
                .successfulOrdersCount(successOrders.size())
                .pendingOrdersCount(pendingOrders.size())
                .revenueTrends(revenueTrends)
                .planSalesBreakdown(planBreakdown)
                .build();

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/trend")
    public ResponseEntity<ApiResponse<List<DailyMetricDto>>> getTrend(
            @RequestParam(defaultValue = "user") String metric,
            @RequestParam(defaultValue = "7days") String period,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {

        LocalDate today = LocalDate.now();
        int targetYear = (year != null && year >= 2000 && year <= 2100) ? year : today.getYear();
        int targetMonth = (month != null && month >= 1 && month <= 12) ? month : today.getMonthValue();

        List<DailyMetricDto> trend = new ArrayList<>();

        if ("range".equalsIgnoreCase(period) || (startDate != null && endDate != null)) {
            LocalDate start = (startDate != null && !startDate.isBlank()) ? LocalDate.parse(startDate) : today.minusDays(30);
            LocalDate end = (endDate != null && !endDate.isBlank()) ? LocalDate.parse(endDate) : today;
            if (end.isBefore(start)) {
                LocalDate temp = start;
                start = end;
                end = temp;
            }
            final LocalDate finalStart = start;
            final LocalDate finalEnd = end;
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && !u.getCreatedAt().toLocalDate().isBefore(finalStart)
                                && !u.getCreatedAt().toLocalDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null
                                && !u.getUsageDate().isBefore(finalStart)
                                && !u.getUsageDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(
                                UserDailyTokenUsage::getUsageDate,
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null
                                && !o.getCreatedAt().toLocalDate().isBefore(finalStart)
                                && !o.getCreatedAt().toLocalDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            }
        } else if ("days_in_month".equalsIgnoreCase(period)) {
            // Từng ngày trong tháng và năm được chọn (e.g. Tháng 10/2026: 01/10 -> 31/10)
            int daysInMonth = java.time.YearMonth.of(targetYear, targetMonth).lengthOfMonth();
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && u.getCreatedAt().getYear() == targetYear
                                && u.getCreatedAt().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null
                                && u.getUsageDate().getYear() == targetYear
                                && u.getUsageDate().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null
                                && o.getCreatedAt().getYear() == targetYear
                                && o.getCreatedAt().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            }
        } else if ("month".equalsIgnoreCase(period)) {
            // 12 tháng trong năm được chọn
            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<Integer, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && u.getCreatedAt().getYear() == targetYear)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().getMonthValue(), Collectors.counting()));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<Integer, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null && u.getUsageDate().getYear() == targetYear)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate().getMonthValue(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<Integer, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null && o.getCreatedAt().getYear() == targetYear)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().getMonthValue(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            }
        } else if ("year".equalsIgnoreCase(period)) {
            // 5 năm gần nhất đến targetYear
            int startYear = targetYear - 4;
            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<Integer, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().getYear(), Collectors.counting()));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<Integer, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate().getYear(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<Integer, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().getYear(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            }
        } else {
            // 7 ngày gần nhất
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");
            List<LocalDate> last7Days = new ArrayList<>();
            for (int i = 6; i >= 0; i--) {
                last7Days.add(today.minusDays(i));
            }

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            }
        }

        return ResponseEntity.ok(ApiResponse.success(trend));
    }
}
