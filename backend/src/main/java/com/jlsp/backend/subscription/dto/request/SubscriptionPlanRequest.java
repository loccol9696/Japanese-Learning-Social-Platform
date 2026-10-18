package com.jlsp.backend.subscription.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubscriptionPlanRequest {

    @NotBlank(message = "Tên gói không được để trống")
    private String name;

    private String code;

    @NotNull(message = "Giá tiền không được để trống")
    @Min(value = 0, message = "Giá tiền tối thiểu là 0")
    private BigDecimal price;

    @NotNull(message = "Thời hạn không được để trống")
    @Min(value = 1, message = "Thời hạn tối thiểu là 1 ngày")
    private Integer durationDays;

    @NotNull(message = "Giới hạn token theo ngày không được để trống")
    @Min(value = 10, message = "Giới hạn token tối thiểu là 10")
    private Integer dailyTokenLimit;

    private String description;

    private String features;

    private Boolean isActive;
}
