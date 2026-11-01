package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.google.GoogleIdentity;
import com.jlsp.backend.auth.google.GoogleTokenVerifier;
import com.jlsp.backend.auth.service.LoginAttemptService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.otp.service.EmailService;
import com.jlsp.backend.otp.service.OtpRedisService;
import com.jlsp.backend.user.entity.AuthProvider;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.Duration;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GoogleLoginTest {

    private UserRepository users;
    private GoogleTokenVerifier verifier;
    private AuthServiceImpl service;

    @BeforeEach
    void setUp() {
        users = mock(UserRepository.class);
        verifier = mock(GoogleTokenVerifier.class);
        RefreshTokenService refresh = mock(RefreshTokenService.class);
        when(refresh.issue(anyLong())).thenReturn("refresh-token");
        when(users.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            if (u.getId() == null) {
                u.setId(100L);
            }
            return u;
        });
        service = new AuthServiceImpl(users, new BCryptPasswordEncoder(4),
                new JwtUtils("test-secret-key-that-is-long-enough-for-hs256!!", "jlsp", Duration.ofMinutes(30)),
                refresh, mock(AccessTokenDenylist.class), new UserMapper(), mock(EmailService.class),
                mock(OtpRedisService.class), mock(LoginAttemptService.class), verifier);
    }

    private static GoogleIdentity identity(boolean verified) {
        return new GoogleIdentity("sub-123", "Sakura.Test@Gmail.com", verified, "Sakura Test", "https://pic/x.png");
    }

    @Test
    void newGoogleUserGetsAnActiveAccountAndTokens() {
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub("sub-123")).thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase("sakura.test@gmail.com")).thenReturn(Optional.empty());

        AuthResponse res = service.loginWithGoogle("tok");

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).save(saved.capture());
        User created = saved.getValue();
        assertThat(created.getEmail()).isEqualTo("sakura.test@gmail.com");
        assertThat(created.getUsername()).isEqualTo("sakura_test");
        assertThat(created.getDisplayName()).isEqualTo("Sakura Test");
        assertThat(created.getAvatarUrl()).isEqualTo("https://pic/x.png");
        assertThat(created.getAuthProvider()).isEqualTo(AuthProvider.GOOGLE);
        assertThat(created.getGoogleSub()).isEqualTo("sub-123");
        assertThat(created.getIsActive()).isTrue();
        assertThat(created.getRole()).isEqualTo(UserRole.USER);
        assertThat(created.getPasswordHash()).isNotBlank();
        assertThat(res.getAccessToken()).isNotBlank();
        assertThat(res.getRefreshToken()).isEqualTo("refresh-token");
    }

    @Test
    void usernameCollisionGetsANumericSuffix() {
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub(anyString())).thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase(anyString())).thenReturn(Optional.empty());
        when(users.existsByUsername("sakura_test")).thenReturn(true);

        service.loginWithGoogle("tok");

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getUsername()).matches("sakura_test\\d{4}");
    }

    @Test
    void returningGoogleUserLogsInWithoutCreatingAnything() {
        User existing = User.builder().id(5L).username("sakura").email("sakura.test@gmail.com")
                .passwordHash("x").isActive(true).googleSub("sub-123").authProvider(AuthProvider.GOOGLE).build();
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub("sub-123")).thenReturn(Optional.of(existing));

        AuthResponse res = service.loginWithGoogle("tok");

        assertThat(res.getUser().getId()).isEqualTo(5L);
        verify(users, never()).save(any());
    }

    @Test
    void existingPasswordAccountWithSameEmailIsLinked() {
        User local = User.builder().id(9L).username("sakura99").email("sakura.test@gmail.com")
                .passwordHash("hash").isActive(true).authProvider(AuthProvider.LOCAL).build();
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub("sub-123")).thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase("sakura.test@gmail.com")).thenReturn(Optional.of(local));

        AuthResponse res = service.loginWithGoogle("tok");

        assertThat(res.getUser().getId()).isEqualTo(9L);
        assertThat(local.getGoogleSub()).isEqualTo("sub-123");
        assertThat(local.getAuthProvider()).isEqualTo(AuthProvider.LOCAL);
        assertThat(local.getPasswordHash()).isEqualTo("hash");
        verify(users).save(local);
    }

    @Test
    void inactiveAccountWithSameEmailIsNotLinkedOrLoggedIn() {
        User banned = User.builder().id(9L).username("sakura99").email("sakura.test@gmail.com")
                .passwordHash("hash").isActive(false).build();
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub(anyString())).thenReturn(Optional.empty());
        when(users.findByEmailIgnoreCase(anyString())).thenReturn(Optional.of(banned));

        assertThatThrownBy(() -> service.loginWithGoogle("tok"))
                .isInstanceOf(AppException.class).hasMessageContaining("khoá");
        assertThat(banned.getGoogleSub()).isNull();
        verify(users, never()).save(any());
    }

    @Test
    void lockedGoogleAccountCannotLogIn() {
        User locked = User.builder().id(5L).username("s").email("e@x.com").passwordHash("x").isActive(false)
                .googleSub("sub-123").build();
        when(verifier.verify("tok")).thenReturn(identity(true));
        when(users.findByGoogleSub("sub-123")).thenReturn(Optional.of(locked));

        assertThatThrownBy(() -> service.loginWithGoogle("tok")).isInstanceOf(AppException.class);
    }

    @Test
    void unverifiedGoogleEmailIsRejected() {
        when(verifier.verify("tok")).thenReturn(identity(false));

        assertThatThrownBy(() -> service.loginWithGoogle("tok"))
                .isInstanceOf(AppException.class).hasMessageContaining("xác minh");
        verify(users, never()).save(any());
    }

    @Test
    void invalidTokenIsPropagated() {
        when(verifier.verify("bad")).thenThrow(new AppException(401, "Phiên đăng nhập Google không hợp lệ"));

        assertThatThrownBy(() -> service.loginWithGoogle("bad")).isInstanceOf(AppException.class);
        verify(users, never()).save(any());
    }

    @Test
    void googleAccountCannotChangePasswordThatDoesNotExist() {
        User google = User.builder().id(5L).username("s").email("e@x.com").passwordHash("x").isActive(true)
                .authProvider(AuthProvider.GOOGLE).build();
        when(users.findById(5L)).thenReturn(Optional.of(google));
        var req = new com.jlsp.backend.auth.dto.request.ChangePasswordRequest();
        req.setOldPassword("whatever");
        req.setNewPassword("NewPassword1!");

        assertThatThrownBy(() -> service.changePassword(5L, req))
                .isInstanceOf(AppException.class).hasMessageContaining("Google");
    }
}
