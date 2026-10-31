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

    @Size(max = 50, message = "Username must not exceed 50 characters")
    private String username;

    @Size(max = 100, message = "Display name must not exceed 100 characters")
    @jakarta.validation.constraints.Pattern(regexp = com.jlsp.backend.auth.dto.request.DisplayNameRules.REGEX,
            message = com.jlsp.backend.auth.dto.request.DisplayNameRules.MESSAGE)
    private String displayName;

    private String email;

    private String avatarUrl;

    private JLPTLevel currentLevel;

    private JLPTLevel jlptLevel;

    @Size(max = 500, message = "Bio must not exceed 500 characters")
    private String bio;

    /** Null: giữ nguyên sở thích hiện tại; tập rỗng: xoá hết. */
    private Set<Long> topicIds;

    @Builder.Default
    private Set<String> interests = new HashSet<>();

    public JLPTLevel getEffectiveLevel() {
        if (currentLevel != null) {
            return currentLevel;
        }
        return jlptLevel;
    }
}
