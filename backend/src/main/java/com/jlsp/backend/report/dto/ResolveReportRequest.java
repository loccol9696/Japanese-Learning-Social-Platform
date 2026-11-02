package com.jlsp.backend.report.dto;

import com.jlsp.backend.report.entity.ReportAction;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ResolveReportRequest {

    @NotNull(message = "Vui lòng chọn hành động xử lý")
    private ReportAction action;

    @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
    private String note;

    /** Nội dung đã sửa; bắt buộc với EDIT_TRANSLATION và EDIT_GRAMMAR. */
    @Valid
    private ReportCorrection correction;
}
