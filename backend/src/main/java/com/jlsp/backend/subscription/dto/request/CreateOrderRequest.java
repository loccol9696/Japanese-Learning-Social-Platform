package com.jlsp.backend.subscription.dto.request;

import lombok.*;

/** Tạo đơn mua gói: chỉ gửi gói muốn mua; người mua luôn lấy từ access token, không từ body. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateOrderRequest {

    private Long planId;

    private String planCode;
}
