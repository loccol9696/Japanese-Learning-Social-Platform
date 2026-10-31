package com.jlsp.backend.onboarding.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.onboarding.OnboardingRules;
import com.jlsp.backend.onboarding.dto.request.OnboardingRequest;
import com.jlsp.backend.onboarding.dto.response.OnboardingStatusResponse;
import com.jlsp.backend.onboarding.service.OnboardingService;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OnboardingServiceImpl implements OnboardingService {

    private final UserRepository userRepository;
    private final TopicService topicService;

    @Override
    @Transactional(readOnly = true)
    public OnboardingStatusResponse getStatus(Long userId) {
        return toStatus(load(userId));
    }

    @Override
    @Transactional
    public OnboardingStatusResponse save(Long userId, OnboardingRequest request) {
        User user = load(userId);
        // Kiểm mọi chủ đề đang bật trước khi ghi; có một cái sai là từ chối cả đáp án.
        Set<com.jlsp.backend.topic.entity.Topic> topics = topicService.requireActive(request.getTopicIds());
        user.setTopics(topics);
        user.setJlptLevel(request.getJlptLevel());
        if (user.getOnboardingCompletedAt() == null) {
            user.setOnboardingCompletedAt(LocalDateTime.now());
        }
        return toStatus(userRepository.save(user));
    }

    @Override
    @Transactional
    public OnboardingStatusResponse skip(Long userId) {
        User user = load(userId);
        if (user.getOnboardingCompletedAt() != null) {
            // Đã trả lời rồi thì bỏ qua không có tác dụng gì.
            return toStatus(user);
        }
        int current = user.getOnboardingSkipCount() == null ? 0 : user.getOnboardingSkipCount();
        user.setOnboardingSkipCount(Math.min(current + 1, OnboardingRules.MAX_SKIPS));
        return toStatus(userRepository.save(user));
    }

    private User load(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));
    }

    private OnboardingStatusResponse toStatus(User user) {
        List<Long> topicIds = user.getTopics().stream()
                .map(t -> t.getId())
                .sorted()
                .collect(Collectors.toList());
        return OnboardingStatusResponse.builder()
                .needed(OnboardingRules.needsOnboarding(user))
                .completed(user.getOnboardingCompletedAt() != null)
                .skipCount(user.getOnboardingSkipCount() == null ? 0 : user.getOnboardingSkipCount())
                .maxSkips(OnboardingRules.MAX_SKIPS)
                .jlptLevel(user.getJlptLevel())
                .topicIds(topicIds)
                .availableTopics(topicService.getActiveTopics())
                .build();
    }
}
