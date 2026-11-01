package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.UserRole;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GeneratedAccountDto {
    private Long id;
    private String username;
    private String password;
    private String email;
    private UserRole role;
    private String displayName;
}
