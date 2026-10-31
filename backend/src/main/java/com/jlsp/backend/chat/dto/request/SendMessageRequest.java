package com.jlsp.backend.chat.dto.request;

import com.jlsp.backend.chat.entity.MessageType;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Gửi tin nhắn (dùng chung cho REST và event Socket.IO "message:send").
 * Cần conversationId hoặc recipientId (khi chưa có hội thoại).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SendMessageRequest {

    private Long conversationId;

    private Long recipientId;

    @NotNull(message = "Thiếu loại tin nhắn")
    private MessageType type;

    @Size(max = 2000, message = "Tin nhắn tối đa 2000 ký tự")
    private String content;

    /** Bắt buộc khi type = VIDEO_SHARE */
    private Long videoId;

    @Min(value = 0, message = "Mốc thời gian không hợp lệ")
    private Integer videoStartMs;

    /** Bắt buộc khi type = IMAGE: URL ảnh đã tải lên Cloudinary */
    @Size(max = 500, message = "Đường dẫn ảnh quá dài")
    private String imageUrl;

    /** Tin được trả lời (tuỳ chọn), phải cùng hội thoại */
    private Long replyToId;

    @Size(max = 64, message = "clientMsgId tối đa 64 ký tự")
    private String clientMsgId;
}
