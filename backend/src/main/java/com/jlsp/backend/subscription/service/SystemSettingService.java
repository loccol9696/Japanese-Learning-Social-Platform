package com.jlsp.backend.subscription.service;

import com.jlsp.backend.subscription.dto.response.TokenRateDto;

public interface SystemSettingService {
    int getSecondsPerToken();
    TokenRateDto getTokenRate();
    TokenRateDto setSecondsPerToken(int seconds);
    int calculateTokensRequired(int durationSeconds);
}
