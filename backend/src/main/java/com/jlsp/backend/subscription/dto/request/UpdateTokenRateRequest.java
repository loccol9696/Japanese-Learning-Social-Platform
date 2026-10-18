package com.jlsp.backend.subscription.dto.request;

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
public class UpdateTokenRateRequest {

    @NotNull(message = "Số giây cho mỗi Token không được để trống")
    @Min(value = 1, message = "Số giây cho mỗi Token tối thiểu là 1")
    private Integer secondsPerToken;
}
