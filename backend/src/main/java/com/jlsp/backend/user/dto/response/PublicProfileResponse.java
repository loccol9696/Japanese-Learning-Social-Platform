package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Hồ sơ công khai của một người dùng: không có email hay thông tin nội bộ. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PublicProfileResponse {

    private Long id;
    private String username;
    private String displayName;
    private String avatarUrl;
    private JLPTLevel jlptLevel;
    private String bio;
    private long followersCount;
    private long followingCount;
    private long likesCount;
    private long videosCount;
    /** Người đang xem có đang theo dõi người này không (false nếu chưa đăng nhập). */
    private boolean isFollowing;
    /** Người đang xem chính là chủ hồ sơ. */
    private boolean isSelf;
}
