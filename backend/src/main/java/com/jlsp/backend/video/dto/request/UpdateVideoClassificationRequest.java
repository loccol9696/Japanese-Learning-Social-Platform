package com.jlsp.backend.video.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;
import java.util.Set;

/**
 * Kiểm duyệt viên sửa phân loại của video (gắn sai chủ đề, hashtag không phù hợp).
 * Trường null thì giữ nguyên, danh sách rỗng thì xoá hết.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateVideoClassificationRequest {

    private Set<Long> topicIds;

    private List<String> hashtags;
}
