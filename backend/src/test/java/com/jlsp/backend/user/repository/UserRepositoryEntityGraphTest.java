package com.jlsp.backend.user.repository;

import org.junit.jupiter.api.Test;
import org.springframework.data.jpa.repository.EntityGraph;

import java.lang.reflect.Method;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Các hàm tìm người dùng dùng trong đăng nhập phải nạp sẵn gói thành viên: UserMapper đọc tên gói ngoài phiên làm việc
 * (open-in-view tắt), nên thiếu nạp sẵn thì người đã mua gói đăng nhập sẽ gặp lỗi 500. Từng có lúc một hàm mới chèn vào
 * giữa làm @EntityGraph "dịch chỗ" sang hàm khác mà không ai biết, nên khoá lại bằng test.
 */
class UserRepositoryEntityGraphTest {

    private static final List<String> LOGIN_LOOKUPS = List.of(
            "findByUsername", "findByEmail", "findByEmailIgnoreCase", "findByGoogleSub", "findById");

    @Test
    void everyLookupUsedByLoginEagerlyLoadsTheSubscriptionPlan() {
        for (String name : LOGIN_LOOKUPS) {
            Method method = java.util.Arrays.stream(UserRepository.class.getMethods())
                    .filter(m -> m.getName().equals(name) && !m.isBridge() && !m.isSynthetic())
                    .findFirst().orElseThrow(() -> new AssertionError("Không có hàm " + name));

            EntityGraph graph = method.getAnnotation(EntityGraph.class);

            assertThat(graph).as("%s phải có @EntityGraph", name).isNotNull();
            assertThat(graph.attributePaths()).as("%s phải nạp subscriptionPlan", name).contains("subscriptionPlan");
        }
    }

    @Test
    void theLockingLookupDoesNotCarryAnAccidentalEntityGraph() throws Exception {
        Method method = UserRepository.class.getMethod("findByIdForUpdate", Long.class);

        assertThat(method.getAnnotation(EntityGraph.class)).isNull();
    }
}
