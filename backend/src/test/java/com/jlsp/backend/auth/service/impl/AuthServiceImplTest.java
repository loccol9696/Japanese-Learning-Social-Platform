package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.request.ChangePasswordRequest;
import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.google.GoogleTokenVerifier;
import com.jlsp.backend.auth.service.LoginAttemptService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.otp.service.EmailService;
import com.jlsp.backend.otp.service.OtpPurpose;
import com.jlsp.backend.otp.service.OtpRedisService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Duration;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthServiceImplTest {

    private final PasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final JwtUtils jwtUtils =
            new JwtUtils("test-secret-key-that-is-long-enough-for-hs256!!", "jlsp", Duration.ofMinutes(30));

    private UserRepository userRepository;
    private RefreshTokenService refreshTokenService;
    private AccessTokenDenylist denylist;
    private EmailService emailService;
    private OtpRedisService otpService;
    private LoginAttemptService loginAttempts;
    private AuthServiceImpl service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        refreshTokenService = mock(RefreshTokenService.class);
        denylist = mock(AccessTokenDenylist.class);
        emailService = mock(EmailService.class);
        otpService = mock(OtpRedisService.class);
        loginAttempts = mock(LoginAttemptService.class);
        when(refreshTokenService.issue(anyLong())).thenReturn("refresh-token");
        service = new AuthServiceImpl(userRepository, encoder, jwtUtils, refreshTokenService, denylist,
                new UserMapper(), emailService, otpService, loginAttempts, mock(GoogleTokenVerifier.class));
    }

    private User user(boolean active, String password) {
        return User.builder().id(7L).username("sakura99").email("sakura@example.com")
                .passwordHash(encoder.encode(password)).role(UserRole.USER).isActive(active).build();
    }

    private static LoginRequest login(String identifier, String password) {
        return LoginRequest.builder().usernameOrEmail(identifier).password(password).build();
    }

    @Test
    void loginWithUnknownEmailGivesSameErrorAsWrongPassword() {
        when(userRepository.findByEmailIgnoreCase("ghost@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.login(login("ghost@example.com", "whatever")))
                .isInstanceOf(AppException.class)
                .hasMessage(AuthServiceImpl.INVALID_CREDENTIALS)
                .extracting("status").isEqualTo(401);
        verify(loginAttempts).recordFailure("ghost@example.com");
    }

    @Test
    void wrongPasswordOnInactiveAccountDoesNotRevealItIsInactive() {
        when(userRepository.findByEmailIgnoreCase("sakura@example.com"))
                .thenReturn(Optional.of(user(false, "correct-pw")));

        assertThatThrownBy(() -> service.login(login("Sakura@Example.com ", "wrong-pw")))
                .isInstanceOf(AppException.class)
                .hasMessage(AuthServiceImpl.INVALID_CREDENTIALS);
    }

    @Test
    void correctPasswordOnInactiveAccountIsForbidden() {
        when(userRepository.findByEmailIgnoreCase("sakura@example.com"))
                .thenReturn(Optional.of(user(false, "correct-pw")));

        assertThatThrownBy(() -> service.login(login("sakura@example.com", "correct-pw")))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(403);
        verify(refreshTokenService, never()).issue(anyLong());
    }

    @Test
    void successfulLoginReturnsBothTokensAndResetsFailures() {
        when(userRepository.findByEmailIgnoreCase("sakura@example.com"))
                .thenReturn(Optional.of(user(true, "correct-pw")));

        AuthResponse response = service.login(login("sakura@example.com", "correct-pw"));

        assertThat(jwtUtils.parse(response.getAccessToken())).get()
                .extracting(JwtUtils.AccessTokenClaims::userId).isEqualTo(7L);
        assertThat(response.getRefreshToken()).isEqualTo("refresh-token");
        assertThat(response.getExpiresIn()).isEqualTo(1800L);
        verify(loginAttempts).reset("sakura@example.com");
    }

    @Test
    void lockedOutLoginStopsBeforeCheckingPassword() {
        AppException locked = new AppException(429, "locked");
        org.mockito.Mockito.doThrow(locked).when(loginAttempts).ensureNotLocked("sakura@example.com");

        assertThatThrownBy(() -> service.login(login("sakura@example.com", "x"))).isSameAs(locked);
        verify(userRepository, never()).findByEmailIgnoreCase(anyString());
    }

    @Test
    void registerStoresLowercaseEmailAndSurvivesMailFailure() {
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(otpService.issue(eq(OtpPurpose.VERIFY_EMAIL), anyString())).thenReturn("123456");
        when(emailService.sendOtpEmail(anyString(), anyString(), any(), anyLong())).thenReturn(false);

        service.register(RegisterRequest.builder().username(" sakura99 ").email(" Sakura@Example.COM ")
                .password("secret1").build());

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(saved.capture());
        assertThat(saved.getValue().getEmail()).isEqualTo("sakura@example.com");
        assertThat(saved.getValue().getUsername()).isEqualTo("sakura99");
        assertThat(saved.getValue().getIsActive()).isFalse();
        assertThat(encoder.matches("secret1", saved.getValue().getPasswordHash())).isTrue();
        verify(otpService).issue(OtpPurpose.VERIFY_EMAIL, "sakura@example.com");
    }

    @Test
    void registerRejectsDuplicateEmailIgnoringCase() {
        when(userRepository.existsByEmailIgnoreCase("sakura@example.com")).thenReturn(true);

        assertThatThrownBy(() -> service.register(RegisterRequest.builder().username("newname")
                .email("SAKURA@example.com").password("secret1").build()))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(409);
    }

    @Test
    void changePasswordRevokesOtherSessionsAndReturnsFreshTokens() {
        User user = user(true, "old-pw");
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        AuthResponse response = service.changePassword(7L,
                ChangePasswordRequest.builder().oldPassword("old-pw").newPassword("new-pw-123").build());

        assertThat(encoder.matches("new-pw-123", user.getPasswordHash())).isTrue();
        verify(refreshTokenService).revokeAll(7L);
        assertThat(response.getAccessToken()).isNotBlank();
    }

    @Test
    void changePasswordRejectsWrongOldPassword() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user(true, "old-pw")));

        assertThatThrownBy(() -> service.changePassword(7L,
                ChangePasswordRequest.builder().oldPassword("nope").newPassword("new-pw-123").build()))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(400);
        verify(refreshTokenService, never()).revokeAll(anyLong());
    }

    @Test
    void forgotPasswordForUnknownEmailSendsNothing() {
        when(userRepository.findByEmailIgnoreCase("ghost@example.com")).thenReturn(Optional.empty());

        service.forgotPassword("ghost@example.com");

        verify(otpService, never()).issue(any(), anyString());
    }

    @Test
    void logoutRevokesRefreshTokenAndDeniesAccessToken() {
        String access = jwtUtils.generateAccessToken(user(true, "pw"));

        service.logout(access, "refresh-token");

        verify(refreshTokenService).revoke("refresh-token");
        verify(denylist).deny(anyString(), any());
    }
}
