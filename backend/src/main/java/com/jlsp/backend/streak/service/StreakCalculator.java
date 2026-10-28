package com.jlsp.backend.streak.service;

import com.jlsp.backend.streak.entity.UserStreak;

import java.time.LocalDate;

/** Quy tắc tính streak, tách khỏi DB để test được các trường hợp biên. */
final class StreakCalculator {

    private StreakCalculator() {
    }

    /** Cập nhật {@code streak} khi người dùng có hoạt động học vào ngày {@code today}. */
    static void recordActivity(UserStreak streak, LocalDate today) {
        LocalDate last = streak.getLastActiveDate();
        if (last == null) {
            streak.setCurrentStreak(1);
        } else if (last.equals(today) || last.isAfter(today)) {
            // Đã tính cho hôm nay (hoặc đồng hồ bị lùi): giữ nguyên.
            return;
        } else if (last.equals(today.minusDays(1))) {
            streak.setCurrentStreak(streak.getCurrentStreak() + 1);
        } else {
            streak.setCurrentStreak(1);
        }
        streak.setLastActiveDate(today);
        streak.setLongestStreak(Math.max(streak.getLongestStreak(), streak.getCurrentStreak()));
    }

    /** Streak đang hiển thị: còn hiệu lực nếu học hôm nay hoặc hôm qua, ngược lại đã đứt. */
    static int effectiveStreak(UserStreak streak, LocalDate today) {
        LocalDate last = streak.getLastActiveDate();
        if (last == null || last.isBefore(today.minusDays(1))) {
            return 0;
        }
        return streak.getCurrentStreak();
    }
}
