package com.jlsp.backend.streak.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.streak.dto.StreakResponse;
import com.jlsp.backend.streak.service.StreakService;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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

    /** GET /api/v1/users/me/streak/days?from=2026-10-01&to=2026-11-07 — các ngày đã học (tối đa 62 ngày). */
    @GetMapping("/days")
    public ResponseEntity<ApiResponse<List<LocalDate>>> getDays(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.success(streakService.days(CurrentUser.requireId(), from, to)));
    }
}
