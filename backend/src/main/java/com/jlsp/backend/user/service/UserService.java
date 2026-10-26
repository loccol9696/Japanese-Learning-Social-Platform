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

    /** Trang cá nhân công khai của một người, kèm quan hệ theo dõi với viewerId. */
    com.jlsp.backend.user.dto.response.PublicProfileResponse getPublicProfile(Long viewerId, Long id);

    PageResponse<UserResponse> getAllUsers(Pageable pageable);

    UserResponse updateUser(Long id, UpdateUserRequest request);

    void deactivateUser(Long id);

    UserResponse createPrivilegedUser(com.jlsp.backend.user.dto.request.AdminCreateUserRequest request);

    /** Tìm người dùng công khai (cho mọi người dùng đăng nhập), kèm quan hệ theo dõi với người tìm. */
    PageResponse<com.jlsp.backend.user.dto.response.FollowUserResponse> searchPublicUsers(
            Long viewerId, String query, Pageable pageable);

    PageResponse<UserResponse> searchUsers(String search, com.jlsp.backend.user.entity.UserRole role, Pageable pageable);

    UserResponse toggleUserStatus(Long id);

    java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto> batchCreateAccounts(com.jlsp.backend.user.dto.request.AdminBatchCreateRequest request);
    UserResponse updateProfileByUsername(String currentUsername, UpdateUserRequest request);
}
