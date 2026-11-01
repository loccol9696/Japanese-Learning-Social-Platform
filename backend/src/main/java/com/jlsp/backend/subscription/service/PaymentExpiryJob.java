package com.jlsp.backend.subscription.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Mỗi phút chuyển các đơn chờ đã quá hạn sang EXPIRED. Lỗi chỉ ghi log, lần sau chạy lại. */
@Component
public class PaymentExpiryJob {

    private static final Logger log = LoggerFactory.getLogger(PaymentExpiryJob.class);

    private final PaymentService paymentService;

    public PaymentExpiryJob(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @Scheduled(fixedDelayString = "${payment.expiry-job-ms:60000}", initialDelayString = "${payment.expiry-job-ms:60000}")
    public void expireOverdueOrders() {
        try {
            int expired = paymentService.expirePendingOrders();
            if (expired > 0) {
                log.info("Đã chuyển {} đơn thanh toán quá hạn sang EXPIRED", expired);
            }
        } catch (RuntimeException e) {
            log.warn("Không dọn được đơn thanh toán quá hạn: {}", e.getMessage());
        }
    }
}
