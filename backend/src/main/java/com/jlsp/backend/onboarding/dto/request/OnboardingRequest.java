package com.jlsp.backend.onboarding.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.Set;

/** Đáp án câu hỏi chào mừng: trình độ và các sở thích (ít nhất 1 chủ đề). */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OnboardingRequest {

    @NotNull(message = "Vui lòng chọn trình độ tiếng Nhật")
    private JLPTLevel jlptLevel;

    @NotNull(message = "Vui lòng chọn ít nhất một sở thích")
    @Size(min = 1, max = 20, message = "Chọn từ 1 đến 20 sở thích")
    private Set<Long> topicIds;
}
