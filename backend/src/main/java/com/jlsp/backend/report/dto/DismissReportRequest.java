package com.jlsp.backend.report.dto;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DismissReportRequest {

    @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
    private String note;
}
