package com.jlsp.backend.common.config;

import com.jlsp.backend.common.config.AdminAccountSeeder.Result;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminAccountSeederTest {

    private UserRepository userRepository;
    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        when(passwordEncoder.encode(any())).thenAnswer(inv -> "hash(" + inv.getArgument(0) + ")");
    }

    private AdminAccountSeeder seeder(String profile, String password, boolean reset) {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profile);
        return new AdminAccountSeeder(userRepository, passwordEncoder, env,
                "admin", "admin@jlsp.com", password, reset);
    }

    @Test
    void neverTouchesAnExistingAdmin() {
        when(userRepository.countByRole(UserRole.ADMIN)).thenReturn(1L);

        assertThat(seeder("prod", "SuperSecret123", false).seed()).isEqualTo(Result.ALREADY_EXISTS);

        verify(userRepository, never()).save(any());
        verify(passwordEncoder, never()).encode(any());
    }

    @Test
    void createsAdminWithThePasswordFromTheEnvironment() {
        assertThat(seeder("prod", "SuperSecret123", false).seed()).isEqualTo(Result.CREATED);

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(UserRole.ADMIN);
        assertThat(saved.getValue().getUsername()).isEqualTo("admin");
        assertThat(saved.getValue().getPasswordHash()).isEqualTo("hash(SuperSecret123)");
    }

    @Test
    void devFallsBackToTheDefaultPasswordWhenNoneIsConfigured() {
        assertThat(seeder("dev", "", false).seed()).isEqualTo(Result.CREATED);

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(saved.capture());
        assertThat(saved.getValue().getPasswordHash())
                .isEqualTo("hash(" + AdminAccountSeeder.DEV_FALLBACK_PASSWORD + ")");
    }

    @Test
    void prodWithoutAPasswordDoesNotCreateAnAdminWithADefaultOne() {
        assertThat(seeder("prod", "", false).seed()).isEqualTo(Result.SKIPPED);

        verify(userRepository, never()).save(any());
    }

    @Test
    void tooShortPasswordIsRejectedEvenInDev() {
        assertThat(seeder("dev", "short", false).seed()).isEqualTo(Result.SKIPPED);

        verify(userRepository, never()).save(any());
    }

    @Test
    void doesNotCreateWhenTheUsernameBelongsToAnotherAccount() {
        when(userRepository.existsByUsername("admin")).thenReturn(true);

        assertThat(seeder("prod", "SuperSecret123", false).seed()).isEqualTo(Result.SKIPPED);

        verify(userRepository, never()).save(any());
    }

    @Test
    void explicitResetChangesOnlyTheAdminPasswordAndReactivatesIt() {
        User admin = User.builder().id(1L).username("admin").role(UserRole.ADMIN)
                .passwordHash("old").isActive(false).build();
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(admin));

        assertThat(seeder("prod", "NewSecret456", true).seed()).isEqualTo(Result.PASSWORD_RESET);

        assertThat(admin.getPasswordHash()).isEqualTo("hash(NewSecret456)");
        assertThat(admin.getIsActive()).isTrue();
        verify(userRepository).save(admin);
    }

    @Test
    void resetNeverTurnsARegularUserIntoAnAdminOrAcceptsAWeakPassword() {
        User regular = User.builder().id(2L).username("admin").role(UserRole.USER).passwordHash("old").build();
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(regular));

        assertThat(seeder("prod", "NewSecret456", true).seed()).isEqualTo(Result.SKIPPED);
        assertThat(seeder("prod", "weak", true).seed()).isEqualTo(Result.SKIPPED);
        assertThat(seeder("prod", "", true).seed()).isEqualTo(Result.SKIPPED);

        assertThat(regular.getPasswordHash()).isEqualTo("old");
        verify(userRepository, never()).save(any());
    }
}
