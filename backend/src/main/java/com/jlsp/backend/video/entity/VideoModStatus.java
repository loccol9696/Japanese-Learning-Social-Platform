package com.jlsp.backend.video.entity;

/**
 * Trạng thái kiểm duyệt video của Moderator:
 * - PENDING: Video đang chờ Moderator kiểm duyệt nội dung.
 * - APPROVED: Moderator đã duyệt chấp thuận, đủ điều kiện hiển thị trên feed.
 * - REJECTED: Moderator từ chối do vi phạm quy chuẩn cộng đồng / bản quyền.
 */
public enum VideoModStatus {
    PENDING,
    APPROVED,
    REJECTED
}
