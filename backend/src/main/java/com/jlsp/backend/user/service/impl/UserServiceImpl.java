package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import org.springframework.security.crypto.password.PasswordEncoder;
import com.jlsp.backend.user.dto.request.AdminCreateUserRequest;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        return null;
    }

    @Override
    public UserResponse createPrivilegedUser(AdminCreateUserRequest request) {
        log.info("Admin creating user '{}' with role '{}'", request.getUsername(), request.getRole());

        if (userRepository.existsByUsername(request.getUsername())) {
            throw new AppException(400, "Username already exists: " + request.getUsername());
        }

        String email = (request.getEmail() != null && !request.getEmail().trim().isEmpty())
                ? request.getEmail().trim()
                : request.getUsername().trim() + "@jlsp.internal";

        if (userRepository.existsByEmail(email)) {
            throw new AppException(400, "Email already exists: " + email);
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(email)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .displayName(request.getDisplayName() != null && !request.getDisplayName().isBlank()
                        ? request.getDisplayName()
                        : request.getUsername())
                .role(request.getRole())
                .isActive(true) // Admin-created accounts are active immediately
                .avatarUrl("https://picsum.photos/seed/" + request.getUsername() + "/120/120")
                .build();

        User savedUser = userRepository.save(user);
        return userMapper.toResponse(savedUser);
    }

    @Override
    public UserResponse getUserById(Long id) {
        return null;
    }

    @Override
    public UserResponse getUserByUsername(String username) {
        return null;
    }

    @Override
    public PageResponse<UserResponse> getAllUsers(Pageable pageable) {
        return null;
    }

    @Override
    public UserResponse updateUser(Long id, UpdateUserRequest request) {
        return null;
    }

    @Override
    public void deactivateUser(Long id) {
        // TODO: Implement
    }
}
