package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;
    private final com.jlsp.backend.video.service.VideoService videoService;

    @PostMapping
    public ResponseEntity<ApiResponse<UserResponse>> createUser(@Valid @RequestBody CreateUserRequest request) {
        UserResponse response = userService.createUser(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "User created successfully", response));
    }

    @PostMapping("/admin-create")
    public ResponseEntity<ApiResponse<UserResponse>> createPrivilegedUser(
            @Valid @RequestBody com.jlsp.backend.user.dto.request.AdminCreateUserRequest request) {
        UserResponse response = userService.createPrivilegedUser(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Account created successfully", response));
    }

    @PostMapping("/admin-batch-create")
    public ResponseEntity<ApiResponse<java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto>>> batchCreateAccounts(
            @Valid @RequestBody com.jlsp.backend.user.dto.request.AdminBatchCreateRequest request) {
        java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto> response = userService.batchCreateAccounts(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Đã tạo thành công " + response.size() + " tài khoản", response));
    }

    @GetMapping("/admin-list")
    public ResponseEntity<ApiResponse<PageResponse<UserResponse>>> getAdminUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "USER") com.jlsp.backend.user.entity.UserRole role,
            @PageableDefault(size = 15, sort = "createdAt", direction = org.springframework.data.domain.Sort.Direction.DESC) Pageable pageable) {
        PageResponse<UserResponse> response = userService.searchUsers(search, role, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PatchMapping("/{id}/toggle-status")
    public ResponseEntity<ApiResponse<UserResponse>> toggleUserStatus(@PathVariable Long id) {
        UserResponse response = userService.toggleUserStatus(id);
        String msg = Boolean.TRUE.equals(response.getIsActive()) ? "Đã mở khóa tài khoản" : "Đã khóa tài khoản";
        return ResponseEntity.ok(ApiResponse.success(200, msg, response));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> getUserById(@PathVariable Long id) {
        UserResponse response = userService.getUserById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<UserResponse>>> getAllUsers(
            @PageableDefault(size = 10, sort = "createdAt") Pageable pageable) {
        PageResponse<UserResponse> response = userService.getAllUsers(pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        User current = CurrentUser.require();
        if (!current.getId().equals(id)) {
            requireAdmin(current);
        }
        UserResponse response = userService.updateUser(id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "User updated successfully", response));
    }

    @PutMapping("/profile-by-username/{username}")
    public ResponseEntity<ApiResponse<UserResponse>> updateProfileByUsername(
            @PathVariable String username,
            @Valid @RequestBody UpdateUserRequest request) {
        User current = CurrentUser.require();
        if (!current.getUsername().equals(username)) {
            requireAdmin(current);
        }
        UserResponse response = userService.updateProfileByUsername(username, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật hồ sơ thành công", response));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable Long id) {
        userService.deactivateUser(id);
        return ResponseEntity.ok(ApiResponse.success(200, "User deactivated successfully", null));
    }

    /**
     * GET /api/v1/users/{id}/videos
     */
    @GetMapping("/{id}/videos")
    public ResponseEntity<ApiResponse<PageResponse<com.jlsp.backend.video.dto.response.VideoResponse>>> getVideosByUserId(
            @PathVariable Long id,
            @PageableDefault(size = 10, sort = "createdAt", direction = org.springframework.data.domain.Sort.Direction.DESC) Pageable pageable) {

        Long viewerId = CurrentUser.idOrNull();
        PageResponse<com.jlsp.backend.video.dto.response.VideoResponse> response = videoService.getVideosByUserId(id,
                viewerId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /** Chỉ ADMIN mới được thao tác trên tài khoản của người khác. */
    private void requireAdmin(User current) {
        if (current.getRole() != UserRole.ADMIN) {
            throw new AppException(HttpStatus.FORBIDDEN.value(), "Bạn không có quyền chỉnh sửa tài khoản này");
        }
    }
}
