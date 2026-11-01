package com.jlsp.backend.subscription.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

/** Admin duyệt tay một đơn (vd. khách chuyển thiếu rồi bù tiền mặt): bắt buộc ghi lý do để truy vết. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminConfirmRequest {

    @NotBlank(message = "Vui lòng ghi lý do duyệt tay")
    @Size(max = 255, message = "Lý do tối đa 255 ký tự")
    private String note;
}
