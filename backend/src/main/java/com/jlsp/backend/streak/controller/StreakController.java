package com.jlsp.backend.streak.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.streak.dto.StreakResponse;
import com.jlsp.backend.streak.service.StreakService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me/streak")
@RequiredArgsConstructor
public class StreakController {

    private final StreakService streakService;

    /** GET /api/v1/users/me/streak — chuỗi ngày học liên tục của người đang đăng nhập. */
    @GetMapping
    public ResponseEntity<ApiResponse<StreakResponse>> getMine() {
        return ResponseEntity.ok(ApiResponse.success(streakService.get(CurrentUser.requireId())));
    }
}
