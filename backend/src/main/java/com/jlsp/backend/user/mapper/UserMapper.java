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
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
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
