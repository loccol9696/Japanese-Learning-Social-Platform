package com.jlsp.backend.common.repository;

import java.util.Collection;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Kết quả của các truy vấn đếm gộp theo nhóm ({@code SELECT x.id AS id, COUNT(..) AS total ... GROUP BY x.id}).
 * Dùng để đếm cho cả một trang dữ liệu bằng MỘT truy vấn thay vì mỗi dòng một truy vấn (N+1).
 */
public interface IdCount {

    Long getId();

    Long getTotal();

    static Map<Long, Long> toMap(Collection<? extends IdCount> counts) {
        return counts.stream().collect(Collectors.toMap(IdCount::getId, IdCount::getTotal));
    }
}
