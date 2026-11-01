package com.jlsp.backend.onboarding;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.onboarding.dto.request.OnboardingRequest;
import com.jlsp.backend.onboarding.dto.response.OnboardingStatusResponse;
import com.jlsp.backend.onboarding.service.impl.OnboardingServiceImpl;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OnboardingServiceImplTest {

    private static final long USER_ID = 7L;

    private UserRepository userRepository;
    private TopicService topicService;
    private OnboardingServiceImpl service;
    private User user;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        topicService = mock(TopicService.class);
        service = new OnboardingServiceImpl(userRepository, topicService);
        user = User.builder().id(USER_ID).username("sakura").role(UserRole.USER).build();
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(topicService.getActiveTopics()).thenReturn(java.util.List.of());
    }

    private static OnboardingRequest request(JLPTLevel level, Set<Long> topics) {
        return OnboardingRequest.builder().jlptLevel(level).topicIds(topics).build();
    }

    // ------------------------------------------------------------------ quy tắc cần hỏi

    @Test
    void aNewOrdinaryUserIsAskedAndAnAdminOrModeratorNever() {
        assertThat(OnboardingRules.needsOnboarding(user)).isTrue();

        User admin = User.builder().role(UserRole.ADMIN).build();
        User moderator = User.builder().role(UserRole.MODERATOR).build();
        assertThat(OnboardingRules.needsOnboarding(admin)).isFalse();
        assertThat(OnboardingRules.needsOnboarding(moderator)).isFalse();
        assertThat(OnboardingRules.needsOnboarding(null)).isFalse();
    }

    @Test
    void aCompletedUserIsNotAskedAgain() {
        user.setOnboardingCompletedAt(java.time.LocalDateTime.now());

        assertThat(OnboardingRules.needsOnboarding(user)).isFalse();
    }

    @Test
    void afterTheMaximumNumberOfSkipsTheUserIsNotAskedAnymore() {
        user.setOnboardingSkipCount(OnboardingRules.MAX_SKIPS - 1);
        assertThat(OnboardingRules.needsOnboarding(user)).isTrue();

        user.setOnboardingSkipCount(OnboardingRules.MAX_SKIPS);
        assertThat(OnboardingRules.needsOnboarding(user)).isFalse();
    }

    // ------------------------------------------------------------------ bỏ qua

    @Test
    void skippingIncreasesTheCountUpToTheCap() {
        service.skip(USER_ID);
        assertThat(user.getOnboardingSkipCount()).isEqualTo(1);

        OnboardingStatusResponse second = service.skip(USER_ID);
        assertThat(user.getOnboardingSkipCount()).isEqualTo(2);
        assertThat(second.isNeeded()).isFalse();

        service.skip(USER_ID);
        assertThat(user.getOnboardingSkipCount()).isEqualTo(OnboardingRules.MAX_SKIPS);
    }

    @Test
    void skippingAfterAnswerIsANoOp() {
        user.setOnboardingCompletedAt(java.time.LocalDateTime.now());

        OnboardingStatusResponse status = service.skip(USER_ID);

        assertThat(user.getOnboardingSkipCount()).isZero();
        assertThat(status.isCompleted()).isTrue();
        verify(userRepository, never()).save(any());
    }

    // ------------------------------------------------------------------ lưu đáp án

    @Test
    void savingStoresTheLevelAndTopicsAndMarksCompleted() {
        Topic anime = Topic.builder().id(1L).name("Anime & Manga").build();
        Topic jlpt = Topic.builder().id(3L).name("Luyện thi JLPT").build();
        when(topicService.requireActive(anyCollection())).thenReturn(Set.of(anime, jlpt));

        OnboardingStatusResponse status = service.save(USER_ID, request(JLPTLevel.N3, Set.of(1L, 3L)));

        assertThat(user.getJlptLevel()).isEqualTo(JLPTLevel.N3);
        assertThat(user.getTopics()).containsExactlyInAnyOrder(anime, jlpt);
        assertThat(user.getOnboardingCompletedAt()).isNotNull();
        assertThat(status.isCompleted()).isTrue();
        assertThat(status.isNeeded()).isFalse();
        assertThat(status.getTopicIds()).containsExactly(1L, 3L);
    }

    @Test
    void savingWithAHiddenOrUnknownTopicIsRejectedAndNothingChanges() {
        when(topicService.requireActive(anyCollection()))
                .thenThrow(new AppException(400, "Có chủ đề không hợp lệ hoặc đã bị ẩn"));

        assertThatThrownBy(() -> service.save(USER_ID, request(JLPTLevel.N5, Set.of(99L))))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(user.getJlptLevel()).isNull();
        assertThat(user.getOnboardingCompletedAt()).isNull();
        verify(userRepository, never()).save(any());
    }

    @Test
    void savingAgainKeepsTheOriginalCompletionTime() {
        java.time.LocalDateTime first = java.time.LocalDateTime.of(2026, 10, 1, 9, 0);
        user.setOnboardingCompletedAt(first);
        when(topicService.requireActive(anyCollection())).thenReturn(Set.of());

        service.save(USER_ID, request(JLPTLevel.N2, Set.of(2L)));

        assertThat(user.getOnboardingCompletedAt()).isEqualTo(first);
        assertThat(user.getJlptLevel()).isEqualTo(JLPTLevel.N2);
    }

    @Test
    void statusOfAMissingUserIsNotFound() {
        when(userRepository.findById(404L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getStatus(404L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
    }
}
