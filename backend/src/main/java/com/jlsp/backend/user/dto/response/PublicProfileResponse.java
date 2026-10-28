package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Trang cá nhân công khai của một người dùng. Không có email / vai trò / trạng
 * thái tài khoản,
 * và có quan hệ theo dõi với người đang xem.
 */

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
    private Long followersCount;
    private Long followingCount;
    private Long likesCount;
    private Long videosCount;

    /** Người đang xem có đang theo dõi người này. */
    private Boolean isFollowing;

    /** Người này có đang theo dõi người đang xem. */
    private Boolean isFollowedBy;

    /** Đây là trang của chính người đang xem. */
    private Boolean isSelf;

    /** Người đang xem đã chặn người này (để hiện nút "Bỏ chặn"). */
    private Boolean isBlocked;
}
