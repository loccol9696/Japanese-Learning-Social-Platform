package com.jlsp.backend.user.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUserRequest {

    @Size(max = 50, message = "Username must not exceed 50 characters")
    private String username;

    @Size(max = 100, message = "Display name must not exceed 100 characters")
    private String displayName;

    private String email;

    private String avatarUrl;

    private JLPTLevel jlptLevel;

    private String bio;
}
