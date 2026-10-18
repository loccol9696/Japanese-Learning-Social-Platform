package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping({"/api/v1/profile", "/profile"})
@RequiredArgsConstructor
public class ProfileController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long userId) {
        UserResponse response = userService.getProfile(userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long userId,
            @Valid @RequestBody UpdateUserRequest request) {
        UserResponse response = userService.updateProfile(userId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Profile updated successfully", response));
    }
}
