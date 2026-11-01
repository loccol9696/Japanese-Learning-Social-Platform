package com.jlsp.backend.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoginRequest {

    /** Email hoặc tên đăng nhập. */
    @NotBlank(message = "Vui lòng nhập email")
    @Size(max = 100, message = "Email tối đa 100 ký tự")
    private String usernameOrEmail;

    @NotBlank(message = "Vui lòng nhập mật khẩu")
    @Size(max = 72, message = "Mật khẩu tối đa 72 ký tự")
    private String password;
}
