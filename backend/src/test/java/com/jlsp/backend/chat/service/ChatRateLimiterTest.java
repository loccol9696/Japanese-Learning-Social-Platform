package com.jlsp.backend.chat.service;

import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ChatRateLimiterTest {

    private static final long WINDOW = 10_000;

    private AtomicLong now;
    private ChatRateLimiter limiter;

    @BeforeEach
    void setUp() {
        now = new AtomicLong(1_000_000);
        limiter = new ChatRateLimiter(3, WINDOW, now::get);
    }

    @Test
    void allowsUpToTheLimitThenRejectsWith429() {
        for (int i = 0; i < 3; i++) {
            limiter.check(1L);
        }

        assertThatThrownBy(() -> limiter.check(1L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(429));
    }

    @Test
    void usersAreLimitedIndependently() {
        for (int i = 0; i < 3; i++) {
            limiter.check(1L);
        }

        assertThatCode(() -> limiter.check(2L)).doesNotThrowAnyException();
    }

    @Test
    void windowSlidesSoOldMessagesStopCounting() {
        limiter.check(1L);
        limiter.check(1L);
        limiter.check(1L);

        now.addAndGet(WINDOW + 1);

        assertThatCode(() -> limiter.check(1L)).doesNotThrowAnyException();
    }

    @Test
    void rejectedAttemptsDoNotExtendTheBlock() {
        for (int i = 0; i < 3; i++) {
            limiter.check(1L);
        }
        now.addAndGet(WINDOW / 2);
        assertThatThrownBy(() -> limiter.check(1L)).isInstanceOf(AppException.class);

        // Hết cửa sổ tính từ tin đầu tiên (không phải từ lần bị từ chối) thì gửi lại được.
        now.addAndGet(WINDOW / 2 + 1);
        assertThatCode(() -> limiter.check(1L)).doesNotThrowAnyException();
    }

    @Test
    void trackersOfIdleUsersAreSweptSoMemoryDoesNotGrowForever() {
        for (long user = 1; user <= 50; user++) {
            limiter.check(user);
        }
        assertThat(limiter.trackedUsers()).isEqualTo(50);

        // Mọi người im lặng quá một cửa sổ; chỉ một người mới gửi tin thì cả 50 bộ đếm cũ bị dọn.
        now.addAndGet(WINDOW * 2);
        limiter.check(999L);

        assertThat(limiter.trackedUsers()).isEqualTo(1);
    }

    @Test
    void activeUsersSurviveTheSweep() {
        limiter.check(1L);
        limiter.check(1L);
        limiter.check(1L);

        now.addAndGet(WINDOW / 2);
        limiter.check(2L); // kích hoạt dọn dẹp (đã quá một cửa sổ kể từ lần dọn trước, mốc 0)

        // Người 1 vẫn còn tin trong cửa sổ nên vẫn bị giới hạn.
        assertThatThrownBy(() -> limiter.check(1L)).isInstanceOf(AppException.class);
    }

    @Test
    void defaultLimiterAllowsATwentyMessageBurst() {
        ChatRateLimiter defaults = new ChatRateLimiter();

        assertThatCode(() -> {
            for (int i = 0; i < 20; i++) {
                defaults.check(1L);
            }
        }).doesNotThrowAnyException();
        assertThatThrownBy(() -> defaults.check(1L)).isInstanceOf(AppException.class);
    }
}
