package com.jlsp.backend.user.mapper;

import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import org.springframework.stereotype.Component;

@Component
public class UserMapper {

    public UserResponse toResponse(User entity) {
        if (entity == null) {
            return null;
        }
        boolean isAdmin = entity.getRole() == com.jlsp.backend.user.entity.UserRole.ADMIN;
        String planName = entity.getSubscriptionPlan() != null 
                ? entity.getSubscriptionPlan().getName() 
                : (isAdmin ? "Quản trị viên (Toàn quyền VIP)" : null);
        java.time.LocalDateTime vipExpire = entity.getVipExpiresAt() != null 
                ? entity.getVipExpiresAt() 
                : (isAdmin ? java.time.LocalDateTime.now().plusYears(100) : null);

        return UserResponse.builder()
                .id(entity.getId())
                .username(entity.getUsername())
                .email(entity.getEmail())
                .displayName(entity.getDisplayName())
                .avatarUrl(entity.getAvatarUrl())
                .jlptLevel(entity.getJlptLevel())
                .bio(entity.getBio())
                .role(entity.getRole())
                .isActive(entity.getIsActive())
                .authProvider(entity.getAuthProvider())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
                .vipExpiresAt(vipExpire)
                .subscriptionPlanName(planName)
                .build();
    }

    public User toEntity(CreateUserRequest request, String encodedPassword) {
        if (request == null) {
            return null;
        }
        return User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .passwordHash(encodedPassword)
                .displayName(request.getDisplayName() != null ? request.getDisplayName() : request.getUsername())
                .jlptLevel(request.getJlptLevel())
                .bio(request.getBio())
                .build();
    }
}