package com.jlsp.backend.flashcard.service.impl;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Tính thứ tự mới khi người dùng chỉ kéo thả trong phần danh sách mà họ đang thấy. */
final class ReorderUtil {

    private ReorderUtil() {
    }

    /**
     * Đặt các id trong {@code requested} vào đúng những vị trí mà chúng đang chiếm trong {@code current}, theo thứ tự
     * mới; các phần tử còn lại giữ nguyên vị trí. Id lạ hoặc trùng bị bỏ qua nên request sai không làm hỏng danh sách.
     */
    static List<Long> apply(List<Long> current, List<Long> requested) {
        Set<Long> known = new HashSet<>(current);
        List<Long> wanted = new ArrayList<>();
        Set<Long> seen = new HashSet<>();
        for (Long id : requested) {
            if (id != null && known.contains(id) && seen.add(id)) {
                wanted.add(id);
            }
        }
        List<Long> result = new ArrayList<>(current);
        int next = 0;
        for (int i = 0; i < result.size(); i++) {
            if (seen.contains(result.get(i))) {
                result.set(i, wanted.get(next++));
            }
        }
        return result;
    }
}
