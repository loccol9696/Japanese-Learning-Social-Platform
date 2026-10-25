package com.jlsp.backend.user.entity;

/** Cách tài khoản được tạo: đăng ký bằng email + mật khẩu hoặc tạo từ đăng nhập Google. */
public enum AuthProvider {
    LOCAL,
    GOOGLE
}
