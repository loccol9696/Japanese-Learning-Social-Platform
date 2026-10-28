package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.List;

/** Danh sách id theo thứ tự mới; có thể chỉ gồm phần đang hiển thị trên máy (xem {@code ReorderUtil}). */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReorderRequest {

    @NotNull(message = "ids is required")
    @Size(max = 2000, message = "Too many ids")
    private List<Long> ids;
}
