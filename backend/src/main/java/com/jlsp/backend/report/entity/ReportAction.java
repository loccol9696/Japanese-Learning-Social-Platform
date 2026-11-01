package com.jlsp.backend.report.entity;

public enum ReportAction {
    /** Không làm gì; chỉ còn để đọc báo cáo cũ và khi không còn biết chủ nội dung. */
    NONE,
    /** Gửi lý do vi phạm cho chủ nội dung và cộng 1 lần vi phạm. */
    WARN_USER,
    HIDE_VIDEO,
    DELETE_COMMENT,
    HIDE_MESSAGE,
    EDIT_TRANSLATION,
    REMOVE_TRANSLATION,
    EDIT_GRAMMAR,
    REMOVE_GRAMMAR,
    LOCK_USER
}
