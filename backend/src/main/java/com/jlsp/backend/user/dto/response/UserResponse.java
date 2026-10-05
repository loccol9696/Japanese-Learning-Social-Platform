package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.topic.dto.response.TopicResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.UserRole;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {

    private Long id;
    private Long userId;
    private String username;
    private String userName;
    private String email;
    private String displayName;
    private String avatarUrl;
    private JLPTLevel currentLevel;
    private JLPTLevel jlptLevel;
    private String bio;
    private String status;
    private UserRole role;
    private String roleName;
    private Boolean isActive;

    @Builder.Default
    private List<TopicResponse> topics = new ArrayList<>();

    @Builder.Default
    private Set<String> interests = new HashSet<>();

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
