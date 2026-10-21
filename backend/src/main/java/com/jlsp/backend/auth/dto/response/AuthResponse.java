package com.jlsp.backend.auth.dto.response;

import com.jlsp.backend.user.dto.response.UserResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {

    @Builder.Default
    private String tokenType = "Bearer";

    private String accessToken;

    /** Thời gian sống của access token (giây). */
    private Long expiresIn;

    private String refreshToken;

    private UserResponse user;
}
