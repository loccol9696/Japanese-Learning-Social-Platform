package com.jlsp.backend.chat.dto.response;

import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Thông tin rút gọn của người dùng hiển thị trong chat. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatUserResponse {

    private Long id;
    private String username;
    private String displayName;
    private String avatarUrl;
    private JLPTLevel jlptLevel;
}
