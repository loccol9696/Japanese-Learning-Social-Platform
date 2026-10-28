package com.jlsp.backend.auth.dto.request;

import jakarta.validation.constraints.Email;
import com.jlsp.backend.auth.validation.StrongPassword;
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
public class RegisterRequest {

    @NotBlank(message = "Vui lòng nhập tên đăng nhập")
    @Size(min = 3, max = 50, message = "Tên đăng nhập phải từ 3 đến 50 ký tự")
    @Pattern(regexp = "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$",
            message = "Tên đăng nhập chỉ gồm chữ cái không dấu, số, dấu chấm hoặc gạch dưới")
    private String username;

    @NotBlank(message = "Vui lòng nhập email")
    @Email(message = "Định dạng email không hợp lệ")
    @Size(max = 100, message = "Email tối đa 100 ký tự")
    private String email;

    @NotBlank(message = "Vui lòng nhập mật khẩu")
    @StrongPassword
    private String password;

    @Size(max = 100, message = "Họ và tên tối đa 100 ký tự")
    private String displayName;
}
