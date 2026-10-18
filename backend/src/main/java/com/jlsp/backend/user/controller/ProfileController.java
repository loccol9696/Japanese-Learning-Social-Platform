package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping({"/api/v1/profile", "/profile"})
@RequiredArgsConstructor
@Slf4j
public class ProfileController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId) {
        Long id = headerUserId != null ? headerUserId : paramUserId;
        if (id == null) {
            id = 1L; // Demo fallback
        }
        UserResponse response = userService.getUserById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId,
            @Valid @RequestBody UpdateUserRequest request) {
        Long id = headerUserId != null ? headerUserId : paramUserId;
        if (id == null) {
            id = 1L;
        }
        UserResponse response = userService.updateUser(id, request);
        log.info("User {} updated profile via /api/v1/profile", id);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật hồ sơ thành công", response));
    }
}
