package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.service.AuthService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.CustomUserDetails;
import com.jlsp.backend.common.security.jwt.JwtUtils;
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
                .isActive(true)
                .build();
        User savedUser = userRepository.save(user);

        CustomUserDetails userDetails = new CustomUserDetails(savedUser);
        String accessToken = jwtUtils.generateToken(userDetails);
        UserResponse userResponse = userMapper.toResponse(savedUser);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .user(userResponse)
                .build();
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        log.info("Processing login for username: {}", request.getUsernameOrEmail());

        User user = userRepository.findByUsername(request.getUsernameOrEmail())
                .orElseGet(() -> userRepository.findByEmail(request.getUsernameOrEmail())
                        .orElseThrow(() -> new AppException(404, "Username/email not found")));

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
}
