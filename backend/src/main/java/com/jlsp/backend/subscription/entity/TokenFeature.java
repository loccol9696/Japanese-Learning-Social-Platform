package com.jlsp.backend.subscription.entity;

/** Tính năng AI tiêu hao token. Thêm giá trị mới khi có tính năng AI mới tính hạn mức. */
public enum TokenFeature {
    /** Tạo phụ đề tự động cho video (nhận dạng giọng nói và dịch). */
    VIDEO_SUBTITLE,
    /** Phân tích ngữ pháp các câu phụ đề. */
    GRAMMAR_ANALYSIS
}
