package com.jlsp.backend.auth.dto.request;

import com.jlsp.backend.auth.validation.StrongPassword;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Đổi mật khẩu cho người dùng đang đăng nhập (danh tính lấy từ access token).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChangePasswordRequest {

    @NotBlank(message = "Vui lòng nhập mật khẩu hiện tại")
    private String oldPassword;

    @NotBlank(message = "Vui lòng nhập mật khẩu mới")
    @StrongPassword(message = "Mật khẩu mới phải từ 8 đến 72 ký tự, gồm cả chữ và số")
    private String newPassword;
}
