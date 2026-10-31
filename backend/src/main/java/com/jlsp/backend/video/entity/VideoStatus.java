package com.jlsp.backend.video.entity;

/**
 * Trạng thái hiển thị của Video trong hệ thống:
 * - PUBLIC: Video công khai, xuất hiện trên Feed chung và tìm kiếm.
 * - PRIVATE: Video riêng tư, chỉ người tạo mới xem được.
 * - UNLISTED: Video không công khai (chỉ xem được khi có đường link trực tiếp).
 * - DRAFT: Bản nháp chưa đăng, người tạo có thể tiếp tục chỉnh sửa rồi đăng sau.
 */
public enum VideoStatus {
    PUBLIC,
    PRIVATE,
    UNLISTED,
    DRAFT
}
