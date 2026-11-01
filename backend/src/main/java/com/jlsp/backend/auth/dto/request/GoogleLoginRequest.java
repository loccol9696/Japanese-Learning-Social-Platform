package com.jlsp.backend.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class GoogleLoginRequest {

    /** Google ID token (JWT) lấy từ đăng nhập Google trên app. */
    @NotBlank(message = "Thiếu thông tin đăng nhập Google")
    @Size(max = 4096, message = "Thông tin đăng nhập Google không hợp lệ")
    private String idToken;
}
