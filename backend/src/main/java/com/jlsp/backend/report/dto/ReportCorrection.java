package com.jlsp.backend.report.dto;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Nội dung bản dịch / mẫu ngữ pháp: kiểm duyệt viên gửi lên khi sửa, và backend trả về để điền sẵn vào
 * form sửa. Bản dịch chỉ dùng translation, ngữ pháp dùng ba trường còn lại.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportCorrection {

    @Size(max = 1000, message = "Bản dịch tối đa 1000 ký tự")
    private String translation;

    @Size(max = 200, message = "Mẫu ngữ pháp tối đa 200 ký tự")
    private String pattern;

    @Size(max = 500, message = "Ý nghĩa tối đa 500 ký tự")
    private String meaning;

    @Size(max = 2000, message = "Giải thích tối đa 2000 ký tự")
    private String explanation;

    @Size(max = 2000, message = "Câu thoại tiếng Nhật tối đa 2000 ký tự")
    private String scriptText;
}
