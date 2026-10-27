package com.jlsp.backend.streak.service;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.streak.dto.StreakResponse;
import com.jlsp.backend.streak.entity.UserStreak;
import com.jlsp.backend.streak.repository.UserStreakDayRepository;
import com.jlsp.backend.streak.repository.UserStreakRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Streak học liên tục. Một ngày được tính khi người dùng ôn ít nhất một thẻ hoặc chấm một câu shadowing.
 * Ranh giới ngày theo giờ Việt Nam, không phụ thuộc múi giờ của máy chủ.
 */
@Service
public class StreakService {

    private static final Logger log = LoggerFactory.getLogger(StreakService.class);
    static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    /** Khoảng ngày tối đa một lần xem lịch (một tháng cộng phần tuần lân cận). */
    static final int MAX_DAYS_RANGE = 62;

    private final UserStreakRepository repository;
    private final UserStreakDayRepository dayRepository;
    private final TransactionTemplate writeTx;
    private final TransactionTemplate readTx;
    private final Clock clock;

    @Autowired
    public StreakService(UserStreakRepository repository, UserStreakDayRepository dayRepository,
                         PlatformTransactionManager transactionManager) {
        this(repository, dayRepository, transactionManager, Clock.system(ZONE));
    }

    StreakService(UserStreakRepository repository, UserStreakDayRepository dayRepository,
                  PlatformTransactionManager transactionManager, Clock clock) {
        this.repository = repository;
        this.dayRepository = dayRepository;
        this.clock = clock;
        // Giao dịch riêng: lỗi streak không được làm hỏng (rollback) việc ôn thẻ / chấm điểm đang chạy.
        this.writeTx = new TransactionTemplate(transactionManager);
        this.writeTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.readTx = new TransactionTemplate(transactionManager);
        this.readTx.setReadOnly(true);
    }

    /** Ghi nhận người dùng vừa học. Không bao giờ ném lỗi: thất bại chỉ được ghi log. */
    public void recordActivity(Long userId) {
        if (userId == null) {
            return;
        }
        try {
            LocalDate today = today();
            writeTx.executeWithoutResult(status -> {
                dayRepository.insertIfAbsent(userId, today);
                repository.insertIfAbsent(userId);
                UserStreak streak = repository.findForUpdate(userId).orElseThrow();
                int before = streak.getCurrentStreak();
                StreakCalculator.recordActivity(streak, today);
                streak.setUpdatedAt(LocalDateTime.now(clock));
                repository.save(streak);
                if (streak.getCurrentStreak() != before) {
                    log.debug("Streak của user {}: {} -> {}", userId, before, streak.getCurrentStreak());
                }
            });
        } catch (RuntimeException e) {
            log.warn("Không ghi được streak của user {}: {}", userId, e.getMessage());
        }
    }

    public StreakResponse get(Long userId) {
        LocalDate today = today();
        UserStreak streak = readTx.execute(status -> repository.findById(userId).orElse(null));
        if (streak == null) {
            return StreakResponse.builder().build();
        }
        return StreakResponse.builder()
                .currentStreak(StreakCalculator.effectiveStreak(streak, today))
                .longestStreak(streak.getLongestStreak())
                .activeToday(today.equals(streak.getLastActiveDate()))
                .lastActiveDate(streak.getLastActiveDate())
                .build();
    }

    /** Các ngày người dùng đã học trong [from, to], cho lịch chuỗi học. */
    public List<LocalDate> days(Long userId, LocalDate from, LocalDate to) {
        if (from == null || to == null || to.isBefore(from)
                || ChronoUnit.DAYS.between(from, to) + 1 > MAX_DAYS_RANGE) {
            throw new AppException(400, "Khoảng ngày không hợp lệ (tối đa " + MAX_DAYS_RANGE + " ngày)");
        }
        return readTx.execute(status -> dayRepository.findDays(userId, from, to));
    }

    private LocalDate today() {
        return LocalDate.now(clock);
    }
}
