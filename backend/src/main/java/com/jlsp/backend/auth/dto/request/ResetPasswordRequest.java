package com.jlsp.backend.auth.dto.request;

import jakarta.validation.constraints.Email;
import com.jlsp.backend.auth.validation.StrongPassword;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ResetPasswordRequest {

    @NotBlank(message = "Vui lòng nhập email")
    @Email(message = "Định dạng email không hợp lệ")
    private String email;

    @NotBlank(message = "Vui lòng nhập mã OTP")
    @Pattern(regexp = "^\\d{6}$", message = "Mã OTP gồm 6 chữ số")
    private String otp;

    @NotBlank(message = "Vui lòng nhập mật khẩu mới")
    @StrongPassword(message = "Mật khẩu mới phải từ 8 đến 72 ký tự, gồm cả chữ và số")
    private String newPassword;
}
