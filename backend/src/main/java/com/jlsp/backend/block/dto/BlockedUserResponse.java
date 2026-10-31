package com.jlsp.backend.block.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/** Một dòng trong danh sách "người đã chặn" của người đang đăng nhập. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BlockedUserResponse {
    private Long id;
    private String username;
    private String displayName;
    private String avatarUrl;
    private LocalDateTime blockedAt;
}
