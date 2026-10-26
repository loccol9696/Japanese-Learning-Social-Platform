package com.jlsp.backend.report.dto;

import com.jlsp.backend.report.entity.ReportReason;
import com.jlsp.backend.report.entity.ReportTargetType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateReportRequest {

    @NotNull(message = "Vui lòng chọn loại đối tượng báo cáo")
    private ReportTargetType targetType;

    @NotNull(message = "Thiếu mã đối tượng báo cáo")
    private Long targetId;

    @NotNull(message = "Vui lòng chọn lý do báo cáo")
    private ReportReason reason;

    @Size(max = 500, message = "Mô tả chi tiết tối đa 500 ký tự")
    private String detail;
}
