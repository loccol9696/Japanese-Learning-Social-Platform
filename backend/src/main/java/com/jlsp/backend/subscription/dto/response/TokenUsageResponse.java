package com.jlsp.backend.subscription.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

/** Lịch sử dùng token AI của người đang đăng nhập trong một tuần hoặc một tháng. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenUsageResponse {

    /** "week" hoặc "month". */
    private String range;
    private LocalDate from;
    private LocalDate to;
    private int totalTokens;

    /** Mọi ngày trong khoảng, ngày không dùng có tokens = 0. */
    private List<DayUsage> days;

    /** Mọi tính năng tiêu hao token (theo thứ tự cố định), tính năng chưa dùng có tokens = 0. */
    private List<FeatureUsage> features;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DayUsage {
        private LocalDate date;
        private int tokens;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class FeatureUsage {
        /** Tên {@code TokenFeature}, ví dụ VIDEO_SUBTITLE. */
        private String feature;
        private int tokens;
    }
}
