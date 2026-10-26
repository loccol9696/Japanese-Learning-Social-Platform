package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

<<<<<<< HEAD
/**
 * Trang cá nhân công khai của một người dùng. Không có email / vai trò / trạng thái tài khoản,
 * và có quan hệ theo dõi với người đang xem.
 */
=======
/** Hồ sơ công khai của một người dùng: không có email hay thông tin nội bộ. */
>>>>>>> 7379961efe19e2fdb33b5c961ebc28fc63418a2a
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
<<<<<<< HEAD

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
=======
    private long followersCount;
    private long followingCount;
    private long likesCount;
    private long videosCount;
    /** Người đang xem có đang theo dõi người này không (false nếu chưa đăng nhập). */
    private boolean isFollowing;
    /** Người đang xem chính là chủ hồ sơ. */
    private boolean isSelf;
>>>>>>> 7379961efe19e2fdb33b5c961ebc28fc63418a2a
}
