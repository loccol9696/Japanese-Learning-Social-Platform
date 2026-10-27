package com.jlsp.backend.chat.dto.request;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Chia sẻ một bộ thẻ từ vựng cho nhiều người cùng lúc (mỗi người nhận một tin DECK_SHARE).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ShareDeckRequest {

    @NotEmpty(message = "Vui lòng chọn ít nhất một người nhận")
    @Size(max = 20, message = "Chỉ chia sẻ tối đa 20 người một lần")
    private List<Long> recipientIds;

    @Size(max = 500, message = "Lời nhắn tối đa 500 ký tự")
    private String note;
}
