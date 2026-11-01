package com.jlsp.backend.topic.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TopicRequest {

    @NotBlank(message = "Tên chủ đề không được để trống")
    @Size(max = 80, message = "Tên chủ đề tối đa 80 ký tự")
    private String name;

    /** Null khi tạo: mặc định hiển thị. */
    private Boolean isActive;

    /** Null: giữ nguyên (khi sửa) hoặc đặt cuối danh sách (khi tạo). */
    private Integer sortOrder;
}
