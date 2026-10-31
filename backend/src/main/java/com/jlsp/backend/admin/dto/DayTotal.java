package com.jlsp.backend.admin.dto;

import java.time.LocalDate;

/**
 * Một dòng kết quả gộp theo ngày cho thống kê quản trị. Tách năm/tháng/ngày thay vì cast sang date
 * để truy vấn chạy giống nhau trên mọi CSDL.
 */
public interface DayTotal {

    Integer getYr();

    Integer getMo();

    Integer getDy();

    /** Số lượng (count) hoặc tổng (sum) của ngày đó. */
    Number getTotal();

    default LocalDate day() {
        return LocalDate.of(getYr(), getMo(), getDy());
    }

    default long value() {
        Number total = getTotal();
        return total == null ? 0L : total.longValue();
    }
}
