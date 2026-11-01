package com.jlsp.backend.admin.service;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.PlanSalesBreakdownDto;
import com.jlsp.backend.admin.dto.DayTotal;
import com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository.PlanSales;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Thống kê cho trang quản trị. Mọi con số được gộp ở CSDL (đếm / SUM / GROUP BY theo ngày trong khoảng
 * cần hiển thị) thay vì tải toàn bộ người dùng, lượt dùng token và đơn hàng về rồi lọc trong bộ nhớ.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminAnalyticsService {

    private static final DateTimeFormatter DAY_LABEL = DateTimeFormatter.ofPattern("dd/MM");

    /** Ba chỉ số có biểu đồ xu hướng. */
    public enum Metric {
        USER, TOKEN, REVENUE;

        static Metric parse(String value) {
            for (Metric m : values()) {
                if (m.name().equalsIgnoreCase(value)) {
                    return m;
                }
            }
            return null;
        }
    }

    private final UserRepository userRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final SubscriptionOrderRepository orderRepository;
    private final SubscriptionPlanRepository planRepository;

    public AdminAnalyticsResponse overview(String period, LocalDate today) {
        long totalUsers = userRepository.countByRole(UserRole.USER);
        long activeUsers = userRepository.countByRoleAndIsActive(UserRole.USER, true);
        long lockedUsers = userRepository.countByRoleAndIsActive(UserRole.USER, false);

        // Tổng quan dùng cùng cách chia kỳ với /trend: "year" = 5 năm, "month" = 12 tháng, còn lại = 7 ngày.
        String normalized = "year".equalsIgnoreCase(period) ? "year"
                : "month".equalsIgnoreCase(period) ? "month" : "7days";

        Long totalTokens = tokenUsageRepository.sumTotalTokensUsed();
        BigDecimal totalRevenueBd = orderRepository.sumTotalAmountByStatus(OrderStatus.SUCCESS);
        long totalRevenue = totalRevenueBd != null ? totalRevenueBd.longValue() : 0L;

        return AdminAnalyticsResponse.builder()
                .totalUsers(totalUsers)
                .activeUsers(activeUsers)
                .lockedUsers(lockedUsers)
                .adminCount(userRepository.countByRole(UserRole.ADMIN))
                .moderatorCount(userRepository.countByRole(UserRole.MODERATOR))
                .learnerCount(totalUsers)
                .userRegistrationTrends(trend(Metric.USER, normalized, null, null, today))
                .totalTokensUsed(totalTokens != null ? totalTokens : 0L)
                .activeTokenUsersCount(tokenUsageRepository.countUsersWithUsage())
                .tokenUsageTrends(trend(Metric.TOKEN, normalized, null, null, today))
                .totalRevenue(totalRevenue)
                .successfulOrdersCount(orderRepository.countByStatus(OrderStatus.SUCCESS))
                .pendingOrdersCount(orderRepository.countByStatus(OrderStatus.PENDING))
                .revenueTrends(trend(Metric.REVENUE, normalized, null, null, today))
                .planSalesBreakdown(planBreakdown(totalRevenue))
                .build();
    }

    /**
     * Xu hướng của một chỉ số. {@code period}: "days_in_month" (từng ngày của tháng/năm chọn), "month"
     * (12 tháng của năm chọn), "year" (5 năm kết thúc ở năm chọn), còn lại là 7 ngày gần nhất.
     * Chỉ số không hợp lệ trả danh sách rỗng.
     */
    public List<DailyMetricDto> trend(String metricName, String period, Integer year, Integer month, LocalDate today) {
        Metric metric = Metric.parse(metricName);
        return metric == null ? List.of() : trend(metric, period, year, month, today);
    }

    List<DailyMetricDto> trend(Metric metric, String period, Integer year, Integer month, LocalDate today) {
        int targetYear = (year != null && year >= 2000 && year <= 2100) ? year : today.getYear();
        int targetMonth = (month != null && month >= 1 && month <= 12) ? month : today.getMonthValue();

        List<DailyMetricDto> result = new ArrayList<>();
        if ("days_in_month".equalsIgnoreCase(period)) {
            YearMonth ym = YearMonth.of(targetYear, targetMonth);
            Map<LocalDate, Long> perDay = perDay(metric, ym.atDay(1), ym.plusMonths(1).atDay(1));
            for (int day = 1; day <= ym.lengthOfMonth(); day++) {
                LocalDate d = ym.atDay(day);
                result.add(new DailyMetricDto(d.format(DAY_LABEL), perDay.getOrDefault(d, 0L)));
            }
        } else if ("month".equalsIgnoreCase(period)) {
            Map<LocalDate, Long> perDay = perDay(metric, LocalDate.of(targetYear, 1, 1), LocalDate.of(targetYear + 1, 1, 1));
            Map<Integer, Long> perMonth = fold(perDay, LocalDate::getMonthValue);
            for (int m = 1; m <= 12; m++) {
                result.add(new DailyMetricDto(String.format("Th%02d", m), perMonth.getOrDefault(m, 0L)));
            }
        } else if ("year".equalsIgnoreCase(period)) {
            int startYear = targetYear - 4;
            Map<LocalDate, Long> perDay = perDay(metric, LocalDate.of(startYear, 1, 1), LocalDate.of(targetYear + 1, 1, 1));
            Map<Integer, Long> perYear = fold(perDay, LocalDate::getYear);
            for (int y = startYear; y <= targetYear; y++) {
                result.add(new DailyMetricDto(String.valueOf(y), perYear.getOrDefault(y, 0L)));
            }
        } else {
            LocalDate first = today.minusDays(6);
            Map<LocalDate, Long> perDay = perDay(metric, first, today.plusDays(1));
            for (LocalDate d = first; !d.isAfter(today); d = d.plusDays(1)) {
                result.add(new DailyMetricDto(d.format(DAY_LABEL), perDay.getOrDefault(d, 0L)));
            }
        }
        return result;
    }

    private Map<LocalDate, Long> perDay(Metric metric, LocalDate from, LocalDate toExclusive) {
        List<DayTotal> rows = switch (metric) {
            case USER -> userRepository.countRegistrationsByDay(
                    UserRole.USER, from.atStartOfDay(), toExclusive.atStartOfDay());
            case TOKEN -> tokenUsageRepository.sumTokensByDay(from, toExclusive);
            case REVENUE -> orderRepository.sumRevenueByDay(
                    OrderStatus.SUCCESS, from.atStartOfDay(), toExclusive.atStartOfDay());
        };
        Map<LocalDate, Long> map = new HashMap<>();
        for (DayTotal row : rows) {
            map.merge(row.day(), row.value(), Long::sum);
        }
        return map;
    }

    private static <K> Map<K, Long> fold(Map<LocalDate, Long> perDay, Function<LocalDate, K> keyOf) {
        Map<K, Long> folded = new HashMap<>();
        perDay.forEach((day, value) -> folded.merge(keyOf.apply(day), value, Long::sum));
        return folded;
    }

    private List<PlanSalesBreakdownDto> planBreakdown(long grandTotalRevenue) {
        Map<String, PlanSales> salesByCode = new HashMap<>();
        for (PlanSales sales : orderRepository.summarizeByPlan(OrderStatus.SUCCESS)) {
            salesByCode.put(sales.getPlanCode(), sales);
        }
        return planRepository.findAll().stream()
                .map(plan -> {
                    PlanSales sales = salesByCode.get(plan.getCode());
                    long revenue = sales == null || sales.getRevenue() == null ? 0L : sales.getRevenue().longValue();
                    long count = sales == null || sales.getSalesCount() == null ? 0L : sales.getSalesCount();
                    double pct = grandTotalRevenue > 0 ? ((double) revenue / grandTotalRevenue * 100.0) : 0.0;
                    return PlanSalesBreakdownDto.builder()
                            .planCode(plan.getCode())
                            .planName(plan.getName())
                            .salesCount(count)
                            .revenue(revenue)
                            .percentage(Math.round(pct * 10.0) / 10.0)
                            .build();
                })
                .toList();
    }
}
