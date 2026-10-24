package com.jlsp.backend.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Dùng cho /auth/refresh (bắt buộc) và /auth/logout (tuỳ chọn). */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RefreshTokenRequest {

    @NotBlank(message = "Thiếu refresh token")
    private String refreshToken;
}
