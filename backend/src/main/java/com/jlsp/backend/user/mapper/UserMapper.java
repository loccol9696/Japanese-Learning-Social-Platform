package com.jlsp.backend.user.mapper;

import com.jlsp.backend.topic.dto.response.TopicResponse;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Component
public class UserMapper {

    public UserResponse toResponse(User entity) {
        if (entity == null) {
            return null;
        }

        List<TopicResponse> topicResponses = entity.getTopics() != null
                ? entity.getTopics().stream()
                .map(t -> TopicResponse.builder()
                        .id(t.getTopicId())
                        .name(t.getTopicName())
                        .build())
                .collect(Collectors.toList())
                : Collections.emptyList();

        Set<String> interests = entity.getTopics() != null
                ? entity.getTopics().stream()
                .map(t -> t.getTopicName())
                .collect(Collectors.toSet())
                : Collections.emptySet();

        String roleName = entity.getRole() != null
                ? entity.getRole().getRoleName()
                : (entity.getRoleEnum() != null ? entity.getRoleEnum().name() : "USER");

        return UserResponse.builder()
                .id(entity.getId())
                .userId(entity.getId())
                .username(entity.getUsername())
                .userName(entity.getUsername())
                .email(entity.getEmail())
                .displayName(entity.getDisplayName())
                .avatarUrl(entity.getAvatarUrl())
                .currentLevel(entity.getCurrentLevel())
                .jlptLevel(entity.getCurrentLevel())
                .bio(entity.getBio())
                .status(entity.getStatus())
                .role(entity.getRoleEnum())
                .roleName(roleName)
                .isActive(entity.getIsActive())
                .topics(topicResponses)
                .interests(interests)
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
                .currentLevel(request.getJlptLevel())
                .bio(request.getBio())
                .build();
    }
}
