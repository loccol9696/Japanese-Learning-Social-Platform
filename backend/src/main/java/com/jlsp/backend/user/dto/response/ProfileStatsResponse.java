package com.jlsp.backend.user.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Số liệu hiển thị trên trang hồ sơ: đang theo dõi, người theo dõi, tổng lượt thích nhận được.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProfileStatsResponse {

    private long followingCount;
    private long followerCount;
    private long likeCount;
}
