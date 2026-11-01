package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.subscription.dto.response.TokenUsageResponse;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.entity.TokenFeature;
import com.jlsp.backend.subscription.entity.TokenUsageEvent;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.PromoCodeRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.TokenUsageEventRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class SubscriptionServiceImplTokenTest {

    private static final long USER_ID = 7L;

    private SubscriptionPlanRepository planRepository;
    private UserDailyTokenUsageRepository usageRepository;
    private UserRepository userRepository;
    private TokenUsageEventRepository eventRepository;
    private SubscriptionServiceImpl service;
    private User user;

    @BeforeEach
    void setUp() {
        planRepository = mock(SubscriptionPlanRepository.class);
        usageRepository = mock(UserDailyTokenUsageRepository.class);
        userRepository = mock(UserRepository.class);
        eventRepository = mock(TokenUsageEventRepository.class);
        service = new SubscriptionServiceImpl(planRepository, usageRepository, userRepository, mock(PromoCodeRepository.class), eventRepository);

        user = User.builder().id(USER_ID).username("hana").build();
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        SubscriptionPlan free = SubscriptionPlan.builder().code("FREE").name("Miễn phí").dailyTokenLimit(50).build();
        when(planRepository.findByCode("FREE")).thenReturn(Optional.of(free));
        when(usageRepository.findByUserIdAndUsageDate(eq(USER_ID), any())).thenReturn(Optional.empty());
    }

    // ------------------------------------------------------------------ ghi nhận mỗi lần trừ

    @Test
    void deductingRecordsTheFeatureTokensAndDay() {
        service.validateAndDeductTokens(USER_ID, 3, TokenFeature.VIDEO_SUBTITLE);

        ArgumentCaptor<UserDailyTokenUsage> usage = ArgumentCaptor.forClass(UserDailyTokenUsage.class);
        verify(usageRepository).save(usage.capture());
        assertThat(usage.getValue().getTokensUsed()).isEqualTo(3);

        ArgumentCaptor<TokenUsageEvent> event = ArgumentCaptor.forClass(TokenUsageEvent.class);
        verify(eventRepository).save(event.capture());
        assertThat(event.getValue().getUser()).isSameAs(user);
        assertThat(event.getValue().getFeature()).isEqualTo(TokenFeature.VIDEO_SUBTITLE);
        assertThat(event.getValue().getTokens()).isEqualTo(3);
        assertThat(event.getValue().getUsageDate()).isEqualTo(LocalDate.now());
    }

    @Test
    void overTheDailyLimitIsRejectedAndNothingIsRecorded() {
        UserDailyTokenUsage already = UserDailyTokenUsage.builder().user(user).usageDate(LocalDate.now())
                .tokensUsed(49).build();
        when(usageRepository.findByUserIdAndUsageDate(eq(USER_ID), any())).thenReturn(Optional.of(already));

        assertThatThrownBy(() -> service.validateAndDeductTokens(USER_ID, 2, TokenFeature.GRAMMAR_ANALYSIS))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));

        assertThat(already.getTokensUsed()).isEqualTo(49);
        verify(usageRepository, never()).save(any());
        verify(eventRepository, never()).save(any());
    }

    @Test
    void aFeatureIsRequired() {
        assertThatThrownBy(() -> service.validateAndDeductTokens(USER_ID, 1, null))
                .isInstanceOf(NullPointerException.class);
    }

    // ------------------------------------------------------------------ thống kê

    private static TokenUsageEventRepository.DayTotal day(LocalDate date, long total) {
        return new TokenUsageEventRepository.DayTotal() {
            @Override
            public LocalDate getUsageDay() {
                return date;
            }

            @Override
            public Long getTotal() {
                return total;
            }
        };
    }

    private static TokenUsageEventRepository.FeatureTotal feature(TokenFeature f, long total) {
        return new TokenUsageEventRepository.FeatureTotal() {
            @Override
            public TokenFeature getFeature() {
                return f;
            }

            @Override
            public Long getTotal() {
                return total;
            }
        };
    }

    @Test
    void weekCoversMondayToSundayWithEmptyDaysFilledWithZero() {
        LocalDate monday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        when(eventRepository.sumByDay(eq(USER_ID), eq(monday), eq(monday.plusDays(6))))
                .thenReturn(List.of(day(monday.plusDays(2), 10), day(monday.plusDays(5), 4)));
        when(eventRepository.sumByFeature(eq(USER_ID), eq(monday), eq(monday.plusDays(6))))
                .thenReturn(List.of(feature(TokenFeature.GRAMMAR_ANALYSIS, 4), feature(TokenFeature.VIDEO_SUBTITLE, 10)));

        TokenUsageResponse response = service.getTokenUsage(USER_ID, "week");

        assertThat(response.getRange()).isEqualTo("week");
        assertThat(response.getFrom()).isEqualTo(monday);
        assertThat(response.getTo()).isEqualTo(monday.plusDays(6));
        assertThat(response.getDays()).hasSize(7);
        assertThat(response.getDays().get(0).getDate()).isEqualTo(monday);
        assertThat(response.getDays()).extracting(TokenUsageResponse.DayUsage::getTokens)
                .containsExactly(0, 0, 10, 0, 0, 4, 0);
        assertThat(response.getTotalTokens()).isEqualTo(14);
    }

    @Test
    void everyFeatureIsListedInAFixedOrderEvenWhenUnused() {
        when(eventRepository.sumByDay(anyLong(), any(), any())).thenReturn(List.of());
        when(eventRepository.sumByFeature(anyLong(), any(), any()))
                .thenReturn(List.of(feature(TokenFeature.GRAMMAR_ANALYSIS, 5)));

        TokenUsageResponse response = service.getTokenUsage(USER_ID, "week");

        assertThat(response.getFeatures()).extracting(TokenUsageResponse.FeatureUsage::getFeature)
                .containsExactly("VIDEO_SUBTITLE", "GRAMMAR_ANALYSIS");
        assertThat(response.getFeatures()).extracting(TokenUsageResponse.FeatureUsage::getTokens)
                .containsExactly(0, 5);
        assertThat(response.getTotalTokens()).isZero();
    }

    @Test
    void monthCoversEveryDayOfTheCurrentMonth() {
        YearMonth month = YearMonth.from(LocalDate.now());
        when(eventRepository.sumByDay(anyLong(), any(), any())).thenReturn(List.of());
        when(eventRepository.sumByFeature(anyLong(), any(), any())).thenReturn(List.of());

        TokenUsageResponse response = service.getTokenUsage(USER_ID, "month");

        assertThat(response.getRange()).isEqualTo("month");
        assertThat(response.getFrom()).isEqualTo(month.atDay(1));
        assertThat(response.getTo()).isEqualTo(month.atEndOfMonth());
        assertThat(response.getDays()).hasSize(month.lengthOfMonth());
    }

    @Test
    void rangeIsCaseInsensitiveAndDefaultsToWeek() {
        when(eventRepository.sumByDay(anyLong(), any(), any())).thenReturn(List.of());
        when(eventRepository.sumByFeature(anyLong(), any(), any())).thenReturn(List.of());

        assertThat(service.getTokenUsage(USER_ID, " MONTH ").getRange()).isEqualTo("month");
        assertThat(service.getTokenUsage(USER_ID, null).getRange()).isEqualTo("week");
    }

    @Test
    void unknownRangeIsRejected() {
        assertThatThrownBy(() -> service.getTokenUsage(USER_ID, "year"))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(eventRepository, never()).sumByDay(anyLong(), any(), any());
    }
}
