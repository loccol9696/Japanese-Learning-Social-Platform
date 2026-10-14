package com.jlsp.backend.googlestt.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TranscriptionSubmitResponse {
    private String taskId;
    private String status; // "PROCESSING"
    private String checkUrl; // URL để client poll kết quả
    private LocalDateTime createdAt;
}
