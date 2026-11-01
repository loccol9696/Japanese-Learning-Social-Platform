package com.jlsp.backend.report.entity;

public enum ReportReason {
    SPAM,
    INAPPROPRIATE,
    HARASSMENT,
    MISINFORMATION,
    COPYRIGHT,
    /** Bản dịch hoặc lời giải thích ngữ pháp bị sai. */
    INACCURATE,
    OTHER
}
