package com.jlsp.backend.otp.service;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class EmailServiceTest {

    private final JavaMailSender mailSender = mock(JavaMailSender.class);
    private final EmailService service = new EmailService(mailSender);

    @Test
    void lockMailGoesToTheOwnerWithTheReason() {
        assertThat(service.sendAccountLockedEmail("owner@example.com", "Hana", "quấy rối hoặc thù ghét")).isTrue();

        ArgumentCaptor<SimpleMailMessage> sent = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender).send(sent.capture());
        assertThat(sent.getValue().getTo()).containsExactly("owner@example.com");
        assertThat(sent.getValue().getSubject()).isEqualTo("Tài khoản của bạn đã bị khóa");
        assertThat(sent.getValue().getText()).contains("Xin chào Hana", "Lý do: quấy rối hoặc thù ghét");
    }

    @Test
    void failedLockMailIsReportedWithoutThrowing() {
        doThrow(new MailSendException("smtp down")).when(mailSender).send(any(SimpleMailMessage.class));

        assertThat(service.sendAccountLockedEmail("owner@example.com", "Hana", "spam")).isFalse();
    }
}
