package com.jlsp.backend.ai.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL) // Ẩn các trường null khi trả về JSON
public class TranscriptionStatusResponse {
    private String taskId;
    private String status; // "PROCESSING", "COMPLETED", "FAILED", "NOT_FOUND"
    private String errorMessage; // Chỉ xuất hiện khi status = FAILED
    private Integer totalSegments; // Tổng số câu/phân đoạn
    private List<ScriptSegment> segments; // Danh sách kết quả khi status = COMPLETED
}
