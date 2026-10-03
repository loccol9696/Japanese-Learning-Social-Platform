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

@Service
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;

    private final UserMapper userMapper;

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        return null;
    }

    @Override
    public UserResponse getUserById(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(404, "This user doesn't exist"));

        UserResponse userResponse = userMapper.toResponse(user);

        return userResponse;
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
