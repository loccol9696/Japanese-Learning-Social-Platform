package com.jlsp.backend.admin.service.impl;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.PlanSalesBreakdownDto;
import com.jlsp.backend.common.projection.DailyTotal;
import com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository.PlanSales;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class AdminAnalyticsServiceImplTest {

    static final LocalDate TODAY = LocalDate.of(2026, 10, 18);

    UserRepository users = mock(UserRepository.class);
    UserDailyTokenUsageRepository tokens = mock(UserDailyTokenUsageRepository.class);
    SubscriptionOrderRepository orders = mock(SubscriptionOrderRepository.class);
    SubscriptionPlanRepository plans = mock(SubscriptionPlanRepository.class);
    AdminAnalyticsServiceImpl service;

    @BeforeEach
    void setUp() {
        ZoneId zone = ZoneId.systemDefault();
        Clock clock = Clock.fixed(TODAY.atStartOfDay(zone).plusHours(10).toInstant(), zone);
        service = new AdminAnalyticsServiceImpl(users, tokens, orders, plans, clock);
    }

    @Test
    void last7DaysQueriesOnlyThatWindowAndFillsMissingDays() {
        when(users.countCreatedPerDay(any(), any(), any())).thenReturn(List.of(
                row(LocalDate.of(2026, 10, 12), 2L),
                row(LocalDate.of(2026, 10, 18), 5L)));

        List<DailyMetricDto> trend = service.getTrend("user", "7days", null, null);

        verify(users).countCreatedPerDay(UserRole.USER,
                LocalDateTime.of(2026, 10, 12, 0, 0), LocalDateTime.of(2026, 10, 19, 0, 0));
        assertThat(trend).extracting(DailyMetricDto::getDateLabel)
                .containsExactly("12/10", "13/10", "14/10", "15/10", "16/10", "17/10", "18/10");
        assertThat(trend).extracting(DailyMetricDto::getValue)
                .containsExactly(2L, 0L, 0L, 0L, 0L, 0L, 5L);
    }

    @Test
    void monthPeriodSumsDaysIntoTwelveMonthsOfTargetYear() {
        when(tokens.sumTokensPerDay(any(), any())).thenReturn(List.of(
                row(LocalDate.of(2025, 3, 3), 10),
                row(LocalDate.of(2025, 3, 20), 15),
                row(LocalDate.of(2025, 12, 31), 1)));

        List<DailyMetricDto> trend = service.getTrend("token", "month", 2025, null);

        verify(tokens).sumTokensPerDay(LocalDate.of(2025, 1, 1), LocalDate.of(2025, 12, 31));
        assertThat(trend).hasSize(12);
        assertThat(trend.get(0).getDateLabel()).isEqualTo("Th01");
        assertThat(trend.get(2)).isEqualTo(new DailyMetricDto("Th03", 25L));
        assertThat(trend.get(11)).isEqualTo(new DailyMetricDto("Th12", 1L));
    }

    @Test
    void yearPeriodCoversFiveYearsAndHandlesBigDecimalRevenue() {
        when(orders.sumAmountPerDay(any(), any(), any())).thenReturn(List.of(
                row(LocalDate.of(2022, 6, 1), new BigDecimal("99000.00")),
                row(LocalDate.of(2026, 1, 2), new BigDecimal("199000.00")),
                row(LocalDate.of(2026, 9, 9), new BigDecimal("1000.00"))));

        List<DailyMetricDto> trend = service.getTrend("revenue", "year", null, null);

        verify(orders).sumAmountPerDay(OrderStatus.SUCCESS,
                LocalDateTime.of(2022, 1, 1, 0, 0), LocalDateTime.of(2027, 1, 1, 0, 0));
        assertThat(trend).extracting(DailyMetricDto::getDateLabel)
                .containsExactly("2022", "2023", "2024", "2025", "2026");
        assertThat(trend).extracting(DailyMetricDto::getValue)
                .containsExactly(99000L, 0L, 0L, 0L, 200000L);
    }

    @Test
    void daysInMonthHandlesLeapYear() {
        List<DailyMetricDto> trend = service.getTrend("user", "days_in_month", 2024, 2);

        assertThat(trend).hasSize(29);
        assertThat(trend.get(28).getDateLabel()).isEqualTo("29/02");
    }

    @Test
    void invalidYearAndMonthFallBackToToday() {
        List<DailyMetricDto> trend = service.getTrend("user", "days_in_month", 1900, 13);

        assertThat(trend).hasSize(31);
        assertThat(trend.get(0).getDateLabel()).isEqualTo("01/10");
    }

    @Test
    void unknownMetricReturnsEmptyWithoutQuerying() {
        assertThat(service.getTrend("bogus", "7days", null, null)).isEmpty();
        verifyNoInteractions(users, tokens, orders);
    }

    @Test
    void overviewUsesAggregatesAndNeverLoadsWholeTables() {
        when(users.countByRole(UserRole.USER)).thenReturn(10L);
        when(users.countByRoleAndIsActive(UserRole.USER, true)).thenReturn(8L);
        when(users.countByRoleAndIsActive(UserRole.USER, false)).thenReturn(2L);
        when(orders.sumTotalAmountByStatus(OrderStatus.SUCCESS)).thenReturn(new BigDecimal("300000"));
        when(orders.countByStatus(OrderStatus.SUCCESS)).thenReturn(3L);
        when(orders.countByStatus(OrderStatus.PENDING)).thenReturn(1L);
        when(tokens.sumTotalTokensUsed()).thenReturn(42L);
        when(tokens.countDistinctActiveUsers()).thenReturn(4L);
        when(plans.findAll()).thenReturn(List.of(plan("VIP", "Gói VIP"), plan("FREE", "Miễn phí")));
        when(orders.summarizeByPlan(OrderStatus.SUCCESS)).thenReturn(List.of(planSales("VIP", 3L, new BigDecimal("300000"))));

        AdminAnalyticsResponse res = service.getAnalytics("7days");

        assertThat(res.getTotalUsers()).isEqualTo(10L);
        assertThat(res.getLearnerCount()).isEqualTo(10L);
        assertThat(res.getActiveUsers()).isEqualTo(8L);
        assertThat(res.getTotalRevenue()).isEqualTo(300000L);
        assertThat(res.getSuccessfulOrdersCount()).isEqualTo(3L);
        assertThat(res.getPendingOrdersCount()).isEqualTo(1L);
        assertThat(res.getTotalTokensUsed()).isEqualTo(42L);
        assertThat(res.getActiveTokenUsersCount()).isEqualTo(4L);
        assertThat(res.getUserRegistrationTrends()).hasSize(7);
        assertThat(res.getPlanSalesBreakdown()).containsExactly(
                new PlanSalesBreakdownDto("VIP", "Gói VIP", 3L, 300000L, 100.0),
                new PlanSalesBreakdownDto("FREE", "Miễn phí", 0L, 0L, 0.0));

        verify(users, never()).findAll();
        verify(tokens, never()).findAll();
        verify(orders, never()).findAll();
        verify(orders, never()).findByStatus(any(OrderStatus.class));
    }

    private static DailyTotal row(LocalDate day, Number total) {
        return new DailyTotal() {
            public LocalDate getDay() {
                return day;
            }

            public Number getTotal() {
                return total;
            }
        };
    }

    private static PlanSales planSales(String code, Long count, Number revenue) {
        return new PlanSales() {
            public String getPlanCode() {
                return code;
            }

            public Long getSalesCount() {
                return count;
            }

            public Number getRevenue() {
                return revenue;
            }
        };
    }

    private static SubscriptionPlan plan(String code, String name) {
        SubscriptionPlan p = new SubscriptionPlan();
        p.setCode(code);
        p.setName(name);
        return p;
    }
}
