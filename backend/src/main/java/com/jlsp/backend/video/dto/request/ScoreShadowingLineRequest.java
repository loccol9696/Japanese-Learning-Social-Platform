package com.jlsp.backend.video.dto.request;

import jakarta.validation.constraints.Size;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScoreShadowingLineRequest {

    /** Câu mà bộ nhận dạng giọng nói của thiết bị nghe được; rỗng nghĩa là không nghe thấy gì. */
    @Size(max = 1000, message = "Câu nhận dạng quá dài")
    private String recognizedText;
}
