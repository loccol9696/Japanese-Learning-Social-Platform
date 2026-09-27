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

    private String refreshToken;

    private Long expiresIn;

    private UserResponse user;
}
