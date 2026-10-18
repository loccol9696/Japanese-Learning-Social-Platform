package com.jlsp.backend.common.config;

import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Admin mẫu chỉ được tạo ở profile dev, và không bao giờ ghi đè tài khoản admin đã có. */
class DataInitializerAdminTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);

    private void ensureAdmin(String... profiles) {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profiles);
        DataInitializer initializer = new DataInitializer(
                users, mock(SubscriptionPlanRepository.class), mock(JdbcTemplate.class), encoder, env);
        ReflectionTestUtils.invokeMethod(initializer, "ensureAdminAccount");
    }

    @Test
    void prodProfileNeverTouchesAdmin() {
        ensureAdmin("prod");

        verify(users, never()).findByUsername(anyString());
        verify(users, never()).save(any());
    }

    @Test
    void existingAdminPasswordAndRoleAreNotOverwritten() {
        when(users.findByUsername("admin")).thenReturn(Optional.of(new User()));

        ensureAdmin("dev");

        verify(users, never()).save(any());
        verify(encoder, never()).encode(anyString());
    }

    @Test
    void devProfileCreatesAdminWhenMissing() {
        when(users.findByUsername("admin")).thenReturn(Optional.empty());
        when(users.findByEmail("admin@jlsp.com")).thenReturn(Optional.empty());
        when(encoder.encode("AdminPassword123@")).thenReturn("hash");
        when(users.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ensureAdmin("dev");

        verify(users).save(org.mockito.ArgumentMatchers.<User>argThat(u ->
                "admin".equals(u.getUsername()) && u.getRole() == UserRole.ADMIN && "hash".equals(u.getPasswordHash())));
        assertThat(true).isTrue();
    }
}
