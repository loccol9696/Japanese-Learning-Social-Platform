package com.jlsp.backend.media.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/** Yêu cầu nhập video từ link YouTube. */
@Data
public class YoutubeImportRequest {

    @NotBlank(message = "Vui lòng nhập link YouTube")
    @Size(max = 500, message = "Link YouTube quá dài")
    private String url;
}

