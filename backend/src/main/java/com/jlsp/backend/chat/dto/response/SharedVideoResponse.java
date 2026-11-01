package com.jlsp.backend.chat.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Thẻ video trong tin nhắn VIDEO_SHARE. available = false khi video đã bị xoá,
 * chuyển riêng tư hoặc không được duyệt — khi đó các trường khác để trống.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SharedVideoResponse {

    private Long id;
    private Boolean available;
    private String title;
    private String thumbnailUrl;
    private String videoUrl;
    private Integer duration;
    private JLPTLevel jlptLevel;
    private Long creatorId;
    private String creatorUsername;
    private String creatorDisplayName;
    private String creatorAvatarUrl;
}
