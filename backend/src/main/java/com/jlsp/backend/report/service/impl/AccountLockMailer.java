package com.jlsp.backend.report.service.impl;

import com.jlsp.backend.otp.service.EmailService;
import com.jlsp.backend.report.event.AccountLockedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Báo lý do qua mail vì người bị khóa đã bị đăng xuất, không còn đọc được thông báo trong app. */
@Component
@RequiredArgsConstructor
public class AccountLockMailer {

    private final EmailService emailService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onAccountLocked(AccountLockedEvent event) {
        emailService.sendAccountLockedEmail(event.email(), event.name(), event.reason());
    }
}
