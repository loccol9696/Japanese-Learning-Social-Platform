package com.jlsp.backend.auth.google;

/** Thông tin người dùng lấy từ Google ID token đã được kiểm tra chữ ký. */
public record GoogleIdentity(String sub, String email, boolean emailVerified, String name, String pictureUrl) {
}
