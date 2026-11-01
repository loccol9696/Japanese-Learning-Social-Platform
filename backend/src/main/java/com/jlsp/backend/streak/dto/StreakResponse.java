package com.jlsp.backend.streak.dto;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDate;

@Value
@Builder
public class StreakResponse {

    /** Số ngày liên tục hiện tại; 0 nếu đã bỏ lỡ từ hôm kia trở về trước. */
    int currentStreak;

    int longestStreak;

    /** Hôm nay đã học chưa. false khi currentStreak &gt; 0 nghĩa là streak sẽ đứt nếu hôm nay không học. */
    boolean activeToday;

    LocalDate lastActiveDate;
}
