package com.jlsp.backend.admin.controller;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.service.AdminAnalyticsService;
import com.jlsp.backend.common.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/analytics")
@RequiredArgsConstructor
public class AdminAnalyticsController {

    private final AdminAnalyticsService analyticsService;

    @GetMapping
    public ResponseEntity<ApiResponse<AdminAnalyticsResponse>> getAnalytics(
            @RequestParam(value = "period", defaultValue = "7days") String period) {
        return ResponseEntity.ok(ApiResponse.success(analyticsService.overview(period, LocalDate.now())));
    }

    @GetMapping("/trend")
    public ResponseEntity<ApiResponse<List<DailyMetricDto>>> getTrend(
            @RequestParam(defaultValue = "user") String metric,
            @RequestParam(defaultValue = "7days") String period,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month) {
        return ResponseEntity.ok(ApiResponse.success(
                analyticsService.trend(metric, period, year, month, LocalDate.now())));
    }
}
