package com.jlsp.backend.user.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import org.springframework.data.domain.Pageable;

public interface UserService {

    UserResponse createUser(CreateUserRequest request);

    UserResponse getUserById(Long id);

    UserResponse getUserByUsername(String username);

    PageResponse<UserResponse> getAllUsers(Pageable pageable);

    UserResponse updateUser(Long id, UpdateUserRequest request);

    void deactivateUser(Long id);

    UserResponse getProfile(Long userId);

    UserResponse updateProfile(Long userId, UpdateUserRequest request);
}
