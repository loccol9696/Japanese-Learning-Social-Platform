package com.jlsp.backend.admin;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.dto.DayTotal;
import com.jlsp.backend.admin.service.AdminAnalyticsService;
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
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminAnalyticsServiceTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 27);

    private UserRepository users;
    private UserDailyTokenUsageRepository tokens;
    private SubscriptionOrderRepository orders;
    private SubscriptionPlanRepository plans;
    private AdminAnalyticsService service;

    @BeforeEach
    void setUp() {
        users = mock(UserRepository.class);
        tokens = mock(UserDailyTokenUsageRepository.class);
        orders = mock(SubscriptionOrderRepository.class);
        plans = mock(SubscriptionPlanRepository.class);
        service = new AdminAnalyticsService(users, tokens, orders, plans);
    }

    private record Row(int yr, int mo, int dy, Number total) implements DayTotal {
        public Integer getYr() { return yr; }
        public Integer getMo() { return mo; }
        public Integer getDy() { return dy; }
        public Number getTotal() { return total; }
    }

    private static DayTotal row(int y, int m, int d, Number total) {
        return new Row(y, m, d, total);
    }

    @Test
    void sevenDayTrendCoversLastSevenDaysAndFillsGaps() {
        when(users.countRegistrationsByDay(eq(UserRole.USER), any(), any()))
                .thenReturn(List.of(row(2026, 10, 27, 4L), row(2026, 10, 21, 1L)));

        List<DailyMetricDto> trend = service.trend("user", "7days", null, null, TODAY);

        assertThat(trend).hasSize(7);
        assertThat(trend.get(0).getDateLabel()).isEqualTo("21/10");
        assertThat(trend.get(0).getValue()).isEqualTo(1);
        assertThat(trend.get(6).getDateLabel()).isEqualTo("27/10");
        assertThat(trend.get(6).getValue()).isEqualTo(4);
        assertThat(trend.subList(1, 6)).allMatch(p -> p.getValue() == 0);
    }

    @Test
    void sevenDayQueryRangeEndsTomorrowExclusive() {
        service.trend("user", "7days", null, null, TODAY);

        verify(users).countRegistrationsByDay(UserRole.USER,
                LocalDateTime.of(2026, 10, 21, 0, 0), LocalDateTime.of(2026, 10, 28, 0, 0));
    }

    @Test
    void monthTrendFoldsDaysIntoTwelveMonths() {
        when(tokens.sumTokensByDay(any(), any())).thenReturn(List.of(
                row(2026, 3, 1, 10L), row(2026, 3, 30, 5L), row(2026, 12, 31, 7L)));

        List<DailyMetricDto> trend = service.trend("token", "month", 2026, null, TODAY);

        assertThat(trend).hasSize(12);
        assertThat(trend.get(2).getDateLabel()).isEqualTo("Th03");
        assertThat(trend.get(2).getValue()).isEqualTo(15);
        assertThat(trend.get(11).getValue()).isEqualTo(7);
        verify(tokens).sumTokensByDay(LocalDate.of(2026, 1, 1), LocalDate.of(2027, 1, 1));
    }

    @Test
    void yearTrendCoversFiveYearsEndingAtTarget() {
        when(orders.sumRevenueByDay(eq(OrderStatus.SUCCESS), any(), any()))
                .thenReturn(List.of(row(2022, 5, 1, new BigDecimal("100000")), row(2026, 1, 1, new BigDecimal("50000"))));

        List<DailyMetricDto> trend = service.trend("revenue", "year", null, null, TODAY);

        assertThat(trend).extracting(DailyMetricDto::getDateLabel)
                .containsExactly("2022", "2023", "2024", "2025", "2026");
        assertThat(trend.get(0).getValue()).isEqualTo(100000);
        assertThat(trend.get(4).getValue()).isEqualTo(50000);
    }

    @Test
    void daysInMonthTrendHasOnePointPerDay() {
        List<DailyMetricDto> trend = service.trend("user", "days_in_month", 2024, 2, TODAY);

        assertThat(trend).hasSize(29);
        assertThat(trend.get(28).getDateLabel()).isEqualTo("29/02");
    }

    @Test
    void outOfRangeYearAndMonthFallBackToToday() {
        List<DailyMetricDto> trend = service.trend("user", "days_in_month", 1, 99, TODAY);

        assertThat(trend).hasSize(31); // tháng 10/2026
        assertThat(trend.get(0).getDateLabel()).isEqualTo("01/10");
    }

    @Test
    void unknownMetricReturnsEmptyWithoutTouchingDatabase() {
        assertThat(service.trend("nope", "7days", null, null, TODAY)).isEmpty();
        org.mockito.Mockito.verifyNoInteractions(users, tokens, orders);
    }

    @Test
    void overviewUsesAggregatesAndNeverLoadsWholeTables() {
        when(users.countByRole(UserRole.USER)).thenReturn(10L);
        when(users.countByRoleAndIsActive(UserRole.USER, true)).thenReturn(8L);
        when(users.countByRoleAndIsActive(UserRole.USER, false)).thenReturn(2L);
        when(users.countByRole(UserRole.ADMIN)).thenReturn(1L);
        when(users.countByRole(UserRole.MODERATOR)).thenReturn(3L);
        when(tokens.sumTotalTokensUsed()).thenReturn(999L);
        when(tokens.countUsersWithUsage()).thenReturn(6L);
        when(orders.sumTotalAmountByStatus(OrderStatus.SUCCESS)).thenReturn(new BigDecimal("300000"));
        when(orders.countByStatus(OrderStatus.SUCCESS)).thenReturn(3L);
        when(orders.countByStatus(OrderStatus.PENDING)).thenReturn(2L);

        SubscriptionPlan vip = new SubscriptionPlan();
        vip.setCode("VIP");
        vip.setName("VIP");
        SubscriptionPlan free = new SubscriptionPlan();
        free.setCode("FREE");
        free.setName("Free");
        when(plans.findAll()).thenReturn(List.of(vip, free));
        PlanSales vipSales = mock(PlanSales.class);
        when(vipSales.getPlanCode()).thenReturn("VIP");
        when(vipSales.getSalesCount()).thenReturn(3L);
        when(vipSales.getRevenue()).thenReturn(new BigDecimal("300000"));
        when(orders.summarizeByPlan(OrderStatus.SUCCESS)).thenReturn(List.of(vipSales));

        AdminAnalyticsResponse r = service.overview("7days", TODAY);

        assertThat(r.getTotalUsers()).isEqualTo(10);
        assertThat(r.getLockedUsers()).isEqualTo(2);
        assertThat(r.getModeratorCount()).isEqualTo(3);
        assertThat(r.getTotalTokensUsed()).isEqualTo(999);
        assertThat(r.getActiveTokenUsersCount()).isEqualTo(6);
        assertThat(r.getSuccessfulOrdersCount()).isEqualTo(3);
        assertThat(r.getPendingOrdersCount()).isEqualTo(2);
        assertThat(r.getUserRegistrationTrends()).hasSize(7);
        assertThat(r.getPlanSalesBreakdown()).hasSize(2);
        assertThat(r.getPlanSalesBreakdown().get(0).getPercentage()).isEqualTo(100.0);
        assertThat(r.getPlanSalesBreakdown().get(1).getRevenue()).isZero();

        org.mockito.Mockito.verify(users, org.mockito.Mockito.never()).findAll();
        org.mockito.Mockito.verify(tokens, org.mockito.Mockito.never()).findAll();
        org.mockito.Mockito.verify(orders, org.mockito.Mockito.never()).findByStatus(any());
    }
}
