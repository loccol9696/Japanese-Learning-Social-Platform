package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.request.ChangePasswordRequest;
import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.request.ResetPasswordRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.service.AuthService;
import com.jlsp.backend.auth.service.LoginAttemptService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.otp.dto.ResendOtpRequest;
import com.jlsp.backend.otp.dto.VerifyOtpRequest;
import com.jlsp.backend.otp.service.EmailService;
import com.jlsp.backend.otp.service.OtpPurpose;
import com.jlsp.backend.otp.service.OtpRedisService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Locale;
import java.util.Optional;

@Service
public class AuthServiceImpl implements AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthServiceImpl.class);

    /** Cùng một thông báo cho "không có tài khoản" và "sai mật khẩu" để không lộ email nào đã đăng ký. */
    static final String INVALID_CREDENTIALS = "Email hoặc mật khẩu không chính xác";
    static final String INACTIVE_ACCOUNT =
            "Tài khoản chưa được kích hoạt hoặc đã bị khoá. Vui lòng xác thực email bằng mã OTP";
    private static final String INVALID_OTP = "Mã OTP không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final RefreshTokenService refreshTokenService;
    private final AccessTokenDenylist accessTokenDenylist;
    private final UserMapper userMapper;
    private final EmailService emailService;
    private final OtpRedisService otpService;
    private final LoginAttemptService loginAttemptService;

    /** Hash giả để thời gian xử lý khi email không tồn tại giống khi sai mật khẩu. */
    private final String dummyPasswordHash;

    public AuthServiceImpl(UserRepository userRepository,
                           PasswordEncoder passwordEncoder,
                           JwtUtils jwtUtils,
                           RefreshTokenService refreshTokenService,
                           AccessTokenDenylist accessTokenDenylist,
                           UserMapper userMapper,
                           EmailService emailService,
                           OtpRedisService otpService,
                           LoginAttemptService loginAttemptService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtils = jwtUtils;
        this.refreshTokenService = refreshTokenService;
        this.accessTokenDenylist = accessTokenDenylist;
        this.userMapper = userMapper;
        this.emailService = emailService;
        this.otpService = otpService;
        this.loginAttemptService = loginAttemptService;
        this.dummyPasswordHash = passwordEncoder.encode("jlsp-dummy-password-for-timing");
    }

    @Override
    public AuthResponse register(RegisterRequest request) {
        String username = request.getUsername().trim();
        String email = normalizeEmail(request.getEmail());

        if (userRepository.existsByUsername(username)) {
            throw new AppException(409, "Tên đăng nhập đã được sử dụng");
        }
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new AppException(409, "Email đã được sử dụng");
        }

        String displayName = request.getDisplayName() != null && !request.getDisplayName().isBlank()
                ? request.getDisplayName().trim()
                : username;

        User savedUser = userRepository.save(User.builder()
                .username(username)
                .email(email)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .displayName(displayName)
                .role(UserRole.USER)
                .isActive(false)
                .build());
        log.info("Đã tạo tài khoản mới (chưa kích hoạt) id={}", savedUser.getId());

        // Gửi sau khi đã lưu: mail lỗi không làm mất tài khoản, người dùng bấm "Gửi lại mã".
        sendOtp(OtpPurpose.VERIFY_EMAIL, email);

        return AuthResponse.builder().user(userMapper.toResponse(savedUser)).build();
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        String identifier = request.getUsernameOrEmail().trim();
        loginAttemptService.ensureNotLocked(identifier);

        Optional<User> found = identifier.contains("@")
                ? userRepository.findByEmailIgnoreCase(normalizeEmail(identifier))
                : userRepository.findByUsername(identifier);

        // Luôn kiểm tra mật khẩu TRƯỚC khi nói gì về trạng thái tài khoản.
        boolean passwordMatches = passwordEncoder.matches(
                request.getPassword(),
                found.map(User::getPasswordHash).orElse(dummyPasswordHash));

        if (found.isEmpty() || !passwordMatches) {
            loginAttemptService.recordFailure(identifier);
            throw new AppException(401, INVALID_CREDENTIALS);
        }
        loginAttemptService.reset(identifier);

        User user = found.get();
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new AppException(403, INACTIVE_ACCOUNT);
        }
        return issueTokens(user);
    }

    @Override
    public AuthResponse refresh(String refreshToken) {
        Long userId = refreshTokenService.consume(refreshToken);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(401, "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại"));
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new AppException(403, INACTIVE_ACCOUNT);
        }
        return issueTokens(user);
    }

    @Override
    public void logout(String accessToken, String refreshToken) {
        refreshTokenService.revoke(refreshToken);
        jwtUtils.parse(accessToken)
                .ifPresent(claims -> accessTokenDenylist.deny(claims.tokenId(), claims.expiresAt()));
    }

    @Override
    public void verifyOtp(VerifyOtpRequest request) {
        String email = normalizeEmail(request.getEmail());
        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new AppException(400, INVALID_OTP));
        if (Boolean.TRUE.equals(user.getIsActive())) {
            throw new AppException(409, "Tài khoản đã được kích hoạt, vui lòng đăng nhập");
        }

        otpService.verify(OtpPurpose.VERIFY_EMAIL, email, request.getOtp());

        user.setIsActive(true);
        userRepository.save(user);
        log.info("Tài khoản id={} đã xác thực email", user.getId());
    }

    @Override
    public void resendOtp(ResendOtpRequest request) {
        String email = normalizeEmail(request.getEmail());
        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản với email này"));
        if (Boolean.TRUE.equals(user.getIsActive())) {
            throw new AppException(409, "Tài khoản đã được kích hoạt, vui lòng đăng nhập");
        }
        if (!sendOtp(OtpPurpose.VERIFY_EMAIL, email)) {
            throw new AppException(503, "Không gửi được email lúc này. Vui lòng thử lại sau");
        }
    }

    @Override
    public void forgotPassword(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        // Email không tồn tại / chưa kích hoạt: im lặng, controller luôn trả cùng một thông báo.
        userRepository.findByEmailIgnoreCase(email)
                .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .ifPresent(user -> sendOtp(OtpPurpose.RESET_PASSWORD, email));
    }

    @Override
    public void resetPassword(ResetPasswordRequest request) {
        String email = normalizeEmail(request.getEmail());
        User user = userRepository.findByEmailIgnoreCase(email)
                .filter(u -> Boolean.TRUE.equals(u.getIsActive()))
                .orElseThrow(() -> new AppException(400, INVALID_OTP));

        otpService.verify(OtpPurpose.RESET_PASSWORD, email, request.getOtp());

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        refreshTokenService.revokeAll(user.getId());
        loginAttemptService.reset(email);
        loginAttemptService.reset(user.getUsername());
        log.info("Tài khoản id={} đã đặt lại mật khẩu", user.getId());
    }

    @Override
    public AuthResponse changePassword(Long userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));

        if (!passwordEncoder.matches(request.getOldPassword(), user.getPasswordHash())) {
            throw new AppException(400, "Mật khẩu hiện tại không chính xác");
        }
        if (passwordEncoder.matches(request.getNewPassword(), user.getPasswordHash())) {
            throw new AppException(400, "Mật khẩu mới phải khác mật khẩu hiện tại");
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        // Đăng xuất mọi thiết bị khác; thiết bị hiện tại nhận cặp token mới.
        refreshTokenService.revokeAll(user.getId());
        log.info("Tài khoản id={} đã đổi mật khẩu", user.getId());
        return issueTokens(user);
    }

    private AuthResponse issueTokens(User user) {
        return AuthResponse.builder()
                .accessToken(jwtUtils.generateAccessToken(user))
                .expiresIn(jwtUtils.getAccessTokenTtl().toSeconds())
                .refreshToken(refreshTokenService.issue(user.getId()))
                .user(userMapper.toResponse(user))
                .build();
    }

    /** @return true nếu email đã được gửi. Lỗi giới hạn tần suất (429) vẫn được ném ra. */
    private boolean sendOtp(OtpPurpose purpose, String email) {
        String code = otpService.issue(purpose, email);
        return emailService.sendOtpEmail(email, code, purpose, otpService.getOtpTtlMinutes());
    }

    static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
