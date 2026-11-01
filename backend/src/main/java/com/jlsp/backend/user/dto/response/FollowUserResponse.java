package com.jlsp.backend.user.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Một dòng trong danh sách "người theo dõi" / "đang theo dõi" của người đang đăng nhập,
 * kèm quan hệ hai chiều để client biết nên hiện nút "Theo dõi lại" hay "Bỏ theo dõi".
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FollowUserResponse {

    private Long id;
    private String username;
    private String displayName;
    private String avatarUrl;
    private JLPTLevel jlptLevel;

    /** Mình đang theo dõi người này. */
    private Boolean isFollowing;

    /** Người này đang theo dõi mình. */
    private Boolean isFollowedBy;

    /** Thời điểm quan hệ theo dõi trong danh sách được tạo. */
    private LocalDateTime followedAt;
}
