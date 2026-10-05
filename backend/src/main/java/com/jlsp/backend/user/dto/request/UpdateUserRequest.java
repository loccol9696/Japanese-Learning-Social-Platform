package com.jlsp.backend.user.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.HashSet;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUserRequest {

    @Size(max = 100, message = "Display name must not exceed 100 characters")
    private String displayName;

    private String avatarUrl;

    private JLPTLevel currentLevel;

    private JLPTLevel jlptLevel;

    @Size(max = 500, message = "Bio must not exceed 500 characters")
    private String bio;

    @Builder.Default
    private Set<Long> topicIds = new HashSet<>();

    @Builder.Default
    private Set<String> interests = new HashSet<>();

    public JLPTLevel getEffectiveLevel() {
        if (currentLevel != null) {
            return currentLevel;
        }
        return jlptLevel;
    }
}
