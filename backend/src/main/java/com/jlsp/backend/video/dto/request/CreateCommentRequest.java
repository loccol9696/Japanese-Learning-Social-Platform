package com.jlsp.backend.video.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class CreateCommentRequest {
    @NotBlank(message = "Nội dung bình luận không được để trống")
    @Size(max = 1000, message = "Bình luận không được vượt quá 1000 ký tự")
    private String content;

    private Long parentId;

    /** Bình luận đang được trả lời (có thể là một phản hồi). Bỏ trống thì coi như trả lời {@code parentId}. */
    private Long replyToId;
}
