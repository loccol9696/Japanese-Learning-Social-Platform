package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.UserRole;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {

    private Long id;
    private String username;
    private String email;
    private String displayName;
    private String avatarUrl;
    private JLPTLevel jlptLevel;
    private String bio;
    private UserRole role;
    private Boolean isActive;

    /** LOCAL hoặc GOOGLE: app dùng để ẩn đổi mật khẩu cho tài khoản Google. */
    private com.jlsp.backend.user.entity.AuthProvider authProvider;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Builder.Default
    private Long followersCount = 0L;

    @Builder.Default
    private Long followingCount = 0L;

    @Builder.Default
    private Long likesCount = 0L;

    @Builder.Default
    private Long videosCount = 0L;

    private LocalDateTime vipExpiresAt;
    private String subscriptionPlanName;

    public JLPTLevel getCurrentLevel() {
        return this.jlptLevel;
    }
}