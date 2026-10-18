package com.jlsp.backend.admin.service.impl;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.PlanSalesBreakdownDto;
import com.jlsp.backend.admin.service.AdminAnalyticsService;
import com.jlsp.backend.common.projection.DailyTotal;
import com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository.PlanSales;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Số liệu dashboard admin. Mọi phép đếm/cộng chạy trong DB (COUNT/SUM/GROUP BY theo ngày);
 * service chỉ gom các tổng theo ngày thành ngày/tháng/năm và gắn nhãn.
 */
@Service
@Transactional(readOnly = true)
public class AdminAnalyticsServiceImpl implements AdminAnalyticsService {

    private static final DateTimeFormatter DAY_LABEL = DateTimeFormatter.ofPattern("dd/MM");

    private final UserRepository userRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final SubscriptionOrderRepository orderRepository;
    private final SubscriptionPlanRepository planRepository;
    private final Clock clock;

    @Autowired
    public AdminAnalyticsServiceImpl(UserRepository userRepository,
                                     UserDailyTokenUsageRepository tokenUsageRepository,
                                     SubscriptionOrderRepository orderRepository,
                                     SubscriptionPlanRepository planRepository) {
        this(userRepository, tokenUsageRepository, orderRepository, planRepository, Clock.systemDefaultZone());
    }

    AdminAnalyticsServiceImpl(UserRepository userRepository,
                              UserDailyTokenUsageRepository tokenUsageRepository,
                              SubscriptionOrderRepository orderRepository,
                              SubscriptionPlanRepository planRepository,
                              Clock clock) {
        this.userRepository = userRepository;
        this.tokenUsageRepository = tokenUsageRepository;
        this.orderRepository = orderRepository;
        this.planRepository = planRepository;
        this.clock = clock;
    }

    @Override
    public AdminAnalyticsResponse getAnalytics(String period) {
        LocalDate today = LocalDate.now(clock);
        Window window = Window.of(period, today.getYear(), today.getMonthValue(), today);

        // Chỉ tính học viên (USER), không tính ADMIN / MODERATOR
        long totalUsers = userRepository.countByRole(UserRole.USER);
        long totalRevenue = toLong(orderRepository.sumTotalAmountByStatus(OrderStatus.SUCCESS));

        return AdminAnalyticsResponse.builder()
                .totalUsers(totalUsers)
                .activeUsers(userRepository.countByRoleAndIsActive(UserRole.USER, true))
                .lockedUsers(userRepository.countByRoleAndIsActive(UserRole.USER, false))
                .adminCount(userRepository.countByRole(UserRole.ADMIN))
                .moderatorCount(userRepository.countByRole(UserRole.MODERATOR))
                .learnerCount(totalUsers)
                .userRegistrationTrends(trend(Metric.USER, window))
                .totalTokensUsed(toLong(tokenUsageRepository.sumTotalTokensUsed()))
                .activeTokenUsersCount(tokenUsageRepository.countDistinctActiveUsers())
                .tokenUsageTrends(trend(Metric.TOKEN, window))
                .totalRevenue(totalRevenue)
                .successfulOrdersCount(orderRepository.countByStatus(OrderStatus.SUCCESS))
                .pendingOrdersCount(orderRepository.countByStatus(OrderStatus.PENDING))
                .revenueTrends(trend(Metric.REVENUE, window))
                .planSalesBreakdown(planBreakdown(totalRevenue))
                .build();
    }

    @Override
    public List<DailyMetricDto> getTrend(String metric, String period, Integer year, Integer month) {
        Metric target = Metric.parse(metric);
        if (target == null) {
            return List.of();
        }
        LocalDate today = LocalDate.now(clock);
        int targetYear = (year != null && year >= 2000 && year <= 2100) ? year : today.getYear();
        int targetMonth = (month != null && month >= 1 && month <= 12) ? month : today.getMonthValue();
        return trend(target, Window.of(period, targetYear, targetMonth, today));
    }

    private List<DailyMetricDto> trend(Metric metric, Window window) {
        Map<LocalDate, Long> totals = new HashMap<>();
        for (DailyTotal row : dailyTotals(metric, window.from(), window.to())) {
            totals.merge(window.granularity().bucket(row.getDay()), toLong(row.getTotal()), Long::sum);
        }

        List<DailyMetricDto> result = new ArrayList<>();
        for (LocalDate bucket = window.from(); !bucket.isAfter(window.to());
             bucket = window.granularity().next(bucket)) {
            result.add(new DailyMetricDto(window.granularity().label(bucket), totals.getOrDefault(bucket, 0L)));
        }
        return result;
    }

    private List<DailyTotal> dailyTotals(Metric metric, LocalDate from, LocalDate to) {
        return switch (metric) {
            case USER -> userRepository.countCreatedPerDay(
                    UserRole.USER, from.atStartOfDay(), to.plusDays(1).atStartOfDay());
            case TOKEN -> tokenUsageRepository.sumTokensPerDay(from, to);
            case REVENUE -> orderRepository.sumAmountPerDay(
                    OrderStatus.SUCCESS, from.atStartOfDay(), to.plusDays(1).atStartOfDay());
        };
    }

    private List<PlanSalesBreakdownDto> planBreakdown(long totalRevenue) {
        Map<String, PlanSales> salesByPlan = new HashMap<>();
        for (PlanSales sales : orderRepository.summarizeByPlan(OrderStatus.SUCCESS)) {
            salesByPlan.put(sales.getPlanCode(), sales);
        }

        return planRepository.findAll().stream()
                .map(plan -> {
                    PlanSales sales = salesByPlan.get(plan.getCode());
                    long revenue = sales != null ? toLong(sales.getRevenue()) : 0L;
                    double pct = totalRevenue > 0 ? ((double) revenue / totalRevenue * 100.0) : 0.0;
                    return PlanSalesBreakdownDto.builder()
                            .planCode(plan.getCode())
                            .planName(plan.getName())
                            .salesCount(sales != null ? sales.getSalesCount() : 0L)
                            .revenue(revenue)
                            .percentage(Math.round(pct * 10.0) / 10.0)
                            .build();
                })
                .toList();
    }

    private static long toLong(Number value) {
        if (value == null) {
            return 0L;
        }
        return value instanceof BigDecimal decimal ? decimal.longValue() : value.longValue();
    }

    enum Metric {
        USER, TOKEN, REVENUE;

        static Metric parse(String value) {
            for (Metric metric : values()) {
                if (metric.name().equalsIgnoreCase(value)) {
                    return metric;
                }
            }
            return null;
        }
    }

    enum Granularity {
        DAY(d -> d, d -> d.plusDays(1), d -> d.format(DAY_LABEL)),
        MONTH(d -> d.withDayOfMonth(1), d -> d.plusMonths(1), d -> String.format("Th%02d", d.getMonthValue())),
        YEAR(d -> d.withDayOfYear(1), d -> d.plusYears(1), d -> String.valueOf(d.getYear()));

        private final Function<LocalDate, LocalDate> bucket;
        private final Function<LocalDate, LocalDate> next;
        private final Function<LocalDate, String> label;

        Granularity(Function<LocalDate, LocalDate> bucket, Function<LocalDate, LocalDate> next,
                    Function<LocalDate, String> label) {
            this.bucket = bucket;
            this.next = next;
            this.label = label;
        }

        LocalDate bucket(LocalDate day) {
            return bucket.apply(day);
        }

        LocalDate next(LocalDate bucketStart) {
            return next.apply(bucketStart);
        }

        String label(LocalDate bucketStart) {
            return label.apply(bucketStart);
        }
    }

    /** Khoảng thời gian [from, to] (tính cả hai đầu) và cách gom nhóm. */
    record Window(LocalDate from, LocalDate to, Granularity granularity) {

        static Window of(String period, int year, int month, LocalDate today) {
            if ("year".equalsIgnoreCase(period)) {
                // 5 năm gần nhất, kết thúc ở năm mục tiêu
                return new Window(LocalDate.of(year - 4, 1, 1), LocalDate.of(year, 12, 31), Granularity.YEAR);
            }
            if ("month".equalsIgnoreCase(period)) {
                return new Window(LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31), Granularity.MONTH);
            }
            if ("days_in_month".equalsIgnoreCase(period)) {
                YearMonth ym = YearMonth.of(year, month);
                return new Window(ym.atDay(1), ym.atEndOfMonth(), Granularity.DAY);
            }
            // Mặc định: 7 ngày gần nhất
            return new Window(today.minusDays(6), today, Granularity.DAY);
        }
    }
}
