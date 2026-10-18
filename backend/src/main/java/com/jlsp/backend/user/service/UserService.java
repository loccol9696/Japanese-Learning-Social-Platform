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

    UserResponse createPrivilegedUser(com.jlsp.backend.user.dto.request.AdminCreateUserRequest request);

    PageResponse<UserResponse> searchUsers(String search, com.jlsp.backend.user.entity.UserRole role, Pageable pageable);

    UserResponse toggleUserStatus(Long id);

    java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto> batchCreateAccounts(com.jlsp.backend.user.dto.request.AdminBatchCreateRequest request);
    UserResponse updateProfileByUsername(String currentUsername, UpdateUserRequest request);

    /** Số đang theo dõi / người theo dõi / tổng lượt thích của người dùng. */
    com.jlsp.backend.user.dto.response.ProfileStatsResponse getProfileStats(Long userId);
}
