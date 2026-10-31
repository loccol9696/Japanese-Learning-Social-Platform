package com.jlsp.backend.chat.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterDeviceRequest {

    @NotBlank(message = "Thiếu token thiết bị")
    @Size(max = 512, message = "Token thiết bị quá dài")
    private String token;

    @NotBlank(message = "Thiếu nền tảng")
    @Pattern(regexp = "android|ios", message = "Nền tảng không hợp lệ")
    private String platform;
}
