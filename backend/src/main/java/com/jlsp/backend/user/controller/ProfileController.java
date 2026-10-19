package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping({"/api/v1/profile", "/profile"})
@RequiredArgsConstructor
@Slf4j
public class ProfileController {

    private final UserService userService;
    private final UserRepository userRepository;

    private Long resolveUserId(Long headerUserId, Long paramUserId) {
        if (headerUserId != null) {
            return headerUserId;
        }
        if (paramUserId != null) {
            return paramUserId;
        }
        try {
            org.springframework.security.core.Authentication auth =
                    org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && auth.getName() != null && !auth.getName().equals("anonymousUser")) {
                Optional<User> userOpt = userRepository.findByUsername(auth.getName());
                if (userOpt.isPresent()) {
                    return userOpt.get().getId();
                }
                return null;
            }
        } catch (Exception ignored) {}
        return 1L; // Demo fallback
    }

    @GetMapping
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId) {
        Long id = resolveUserId(headerUserId, paramUserId);
        UserResponse response = userService.getUserById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId,
            @Valid @RequestBody UpdateUserRequest request) {
        Long id = resolveUserId(headerUserId, paramUserId);
        UserResponse response = userService.updateUser(id, request);
        log.info("User {} updated profile via /api/v1/profile", id);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật hồ sơ thành công", response));
    }
}
