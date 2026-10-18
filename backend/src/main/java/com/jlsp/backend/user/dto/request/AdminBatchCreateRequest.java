package com.jlsp.backend.user.dto.request;

import com.jlsp.backend.user.entity.UserRole;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminBatchCreateRequest {

    @Min(value = 1, message = "Số lượng tài khoản phải ít nhất là 1")
    @Max(value = 100, message = "Tối đa tạo 100 tài khoản mỗi lần")
    private int count;

    @NotNull(message = "Vai trò (Role) không được để trống")
    private UserRole role;
}
