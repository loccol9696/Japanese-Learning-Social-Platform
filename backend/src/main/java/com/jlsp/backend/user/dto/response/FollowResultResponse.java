package com.jlsp.backend.user.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FollowResultResponse {

    /** Trạng thái sau khi bấm: true = đang theo dõi. */
    private boolean following;
    private long followersCount;
}
