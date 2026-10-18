package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.service.AuthService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.CustomUserDetails;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.otp.service.EmailService;
import com.jlsp.backend.otp.service.OtpRedisService;
import com.jlsp.backend.otp.dto.ResendOtpRequest;
import com.jlsp.backend.otp.dto.VerifyOtpRequest;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;

import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;

    private final PasswordEncoder passwordEncoder;

    private final JwtUtils jwtUtils;

    private final UserMapper userMapper;

    private final AuthenticationManager authenticationManager;

    private final EmailService emailService;

    private final OtpRedisService otpRedisService;

    @Override
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        log.info("Processing registration for username: {}", request.getUsername());

        if (userRepository.existsByUsername(request.getUsername())) {
            throw new AppException("Username already exists");
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new AppException("Email already exists");
        }

        String encodedPassword = passwordEncoder.encode(request.getPassword());

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .passwordHash(encodedPassword)
                .displayName(request.getDisplayName() != null ? request.getDisplayName() : request.getUsername())
                .role(UserRole.USER)
                .isActive(false)
                .build();
        User savedUser = userRepository.save(user);

        String otp = emailService.generateOtp();
        otpRedisService.saveOtp(request.getEmail(), otp);
        emailService.sendOtpEmail(request.getEmail(), otp);

        UserResponse userResponse = userMapper.toResponse(savedUser);

        return AuthResponse.builder()
                .user(userResponse)
                .build();
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        log.info("Processing login for username: {}", request.getUsernameOrEmail());

        User user = userRepository.findByUsername(request.getUsernameOrEmail())
                .orElseGet(() -> userRepository.findByEmail(request.getUsernameOrEmail())
                        .orElseThrow(() -> new AppException(404, "Username/email not found")));

        if (!user.getIsActive())
            throw new AppException("This user is inactive. Please activate your account.");

        authenticationManager
                .authenticate(new UsernamePasswordAuthenticationToken(user.getUsername(), request.getPassword()));

        CustomUserDetails userDetails = new CustomUserDetails(user);
        String accessToken = jwtUtils.generateToken(userDetails);

        UserResponse userResponse = userMapper.toResponse(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .user(userResponse)
                .build();
    }

    @Transactional
    public void verifyOtp(VerifyOtpRequest request) {
        boolean isValid = otpRedisService.validateOtp(request.getEmail(), request.getOtp());
        if (!isValid) {
            throw new AppException(400, "OTP is wrong or expired. Try again");
        }

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new AppException(404, "This user is not found"));

        user.setIsActive(true);
        userRepository.save(user);
        otpRedisService.deleteOtp(request.getEmail());
    }

    @Transactional
    public void resendOtp(ResendOtpRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new AppException(404, "This user is not found"));

        if (user.getIsActive()) {
            throw new AppException("This user is already activated before");
        }

        String newOtp = emailService.generateOtp();
        otpRedisService.saveOtp(request.getEmail(), newOtp);
        emailService.sendOtpEmail(request.getEmail(), newOtp);
    }

    @Override
    @Transactional
    public void changePassword(String username, Long userId, com.jlsp.backend.auth.dto.request.ChangePasswordRequest request) {
        log.info("Processing password change request for username: {}, userId: {}", username, userId);

        User user = null;
        if (username != null && !username.isBlank()) {
            user = userRepository.findByUsername(username)
                    .orElseGet(() -> userRepository.findByEmail(username).orElse(null));
        }

        if (user == null && userId != null) {
            user = userRepository.findById(userId).orElse(null);
        }

        if (user == null && request.getUsername() != null && !request.getUsername().isBlank()) {
            user = userRepository.findByUsername(request.getUsername())
                    .orElseGet(() -> userRepository.findByEmail(request.getUsername()).orElse(null));
        }

        if (user == null) {
            throw new AppException(404, "Không tìm thấy thông tin tài khoản người dùng");
        }

        if (!passwordEncoder.matches(request.getOldPassword(), user.getPasswordHash())) {
            throw new AppException(400, "Mật khẩu hiện tại không chính xác");
        }

        if (request.getNewPassword().length() < 6) {
            throw new AppException(400, "Mật khẩu mới phải có ít nhất 6 ký tự");
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        log.info("Password successfully changed for user: {}", user.getUsername());
    }
}
