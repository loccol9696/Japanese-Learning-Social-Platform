package com.jlsp.backend.report.entity;

public enum ReportTargetType {
    VIDEO,
    COMMENT,
    USER,
    /** Một tin nhắn; chỉ người trong cuộc trò chuyện mới báo cáo được. */
    MESSAGE,
    /** Bản dịch của một câu phụ đề; targetId là video, targetKey là vị trí câu. */
    TRANSLATION,
    /** Một mẫu ngữ pháp của câu phụ đề; targetId là video, targetKey là "vị trí câu:mẫu". */
    GRAMMAR
}
