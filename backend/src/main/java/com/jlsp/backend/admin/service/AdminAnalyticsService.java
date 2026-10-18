package com.jlsp.backend.admin.service;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;

import java.util.List;

public interface AdminAnalyticsService {

    /**
     * Tổng quan dashboard admin.
     *
     * @param period "7days" (mặc định), "month" (12 tháng năm nay) hoặc "year" (5 năm gần nhất)
     */
    AdminAnalyticsResponse getAnalytics(String period);

    /**
     * Chuỗi số liệu của một chỉ số.
     *
     * @param metric "user", "token" hoặc "revenue" (khác -> danh sách rỗng)
     * @param period "7days" (mặc định), "days_in_month", "month" hoặc "year"
     * @param year   năm mục tiêu (2000-2100, mặc định năm nay)
     * @param month  tháng mục tiêu cho "days_in_month" (1-12, mặc định tháng này)
     */
    List<DailyMetricDto> getTrend(String metric, String period, Integer year, Integer month);
}
