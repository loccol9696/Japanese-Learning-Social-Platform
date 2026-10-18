package com.jlsp.backend.common.projection;

import java.time.LocalDate;

/**
 * Kết quả gom nhóm theo ngày từ query {@code GROUP BY} (alias {@code day}, {@code total}).
 * {@code total} là Number vì COUNT trả Long còn SUM(amount) trả BigDecimal.
 */
public interface DailyTotal {

    LocalDate getDay();

    Number getTotal();
}
