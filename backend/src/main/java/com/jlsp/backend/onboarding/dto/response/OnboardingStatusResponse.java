package com.jlsp.backend.onboarding.dto.response;

import com.jlsp.backend.topic.dto.TopicResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.*;

import java.util.List;

/** Trạng thái câu hỏi chào mừng: có cần hỏi không, đáp án hiện có, và danh sách lựa chọn để app vẽ. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OnboardingStatusResponse {

    private boolean needed;
    private boolean completed;
    private int skipCount;
    private int maxSkips;
    private JLPTLevel jlptLevel;
    private List<Long> topicIds;
    private List<TopicResponse> availableTopics;
}
