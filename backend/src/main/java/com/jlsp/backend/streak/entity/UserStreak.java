package com.jlsp.backend.streak.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Chuỗi ngày học liên tục của một người dùng. Bảng riêng (không thêm cột vào {@code users}) vì dòng này được
 * ghi mỗi ngày học còn bảng người dùng thì đọc rất nhiều.
 */
@Entity
@Table(name = "user_streaks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserStreak {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "current_streak", nullable = false)
    @Builder.Default
    private int currentStreak = 0;

    @Column(name = "longest_streak", nullable = false)
    @Builder.Default
    private int longestStreak = 0;

    /** Ngày (theo múi giờ của {@code StreakService}) có hoạt động học gần nhất. */
    @Column(name = "last_active_date")
    private LocalDate lastActiveDate;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
