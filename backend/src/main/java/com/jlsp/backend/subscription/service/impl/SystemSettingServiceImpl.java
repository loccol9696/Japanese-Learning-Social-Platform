package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.subscription.dto.response.TokenRateDto;
import com.jlsp.backend.subscription.entity.SystemSetting;
import com.jlsp.backend.subscription.repository.SystemSettingRepository;
import com.jlsp.backend.subscription.service.SystemSettingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.concurrent.atomic.AtomicInteger;

@Service
@RequiredArgsConstructor
@Slf4j
public class SystemSettingServiceImpl implements SystemSettingService {

    public static final String KEY_SECONDS_PER_TOKEN = "SECONDS_PER_TOKEN";
    public static final int DEFAULT_SECONDS_PER_TOKEN = 60;

    private final SystemSettingRepository settingRepository;
    private final AtomicInteger cachedSecondsPerToken = new AtomicInteger(-1);

    @Override
    public int getSecondsPerToken() {
        int cached = cachedSecondsPerToken.get();
        if (cached > 0) {
            return cached;
        }

        int val = settingRepository.findBySettingKey(KEY_SECONDS_PER_TOKEN)
                .map(s -> {
                    try {
                        return Integer.parseInt(s.getSettingValue().trim());
                    } catch (NumberFormatException e) {
                        return DEFAULT_SECONDS_PER_TOKEN;
                    }
                })
                .orElse(DEFAULT_SECONDS_PER_TOKEN);

        cachedSecondsPerToken.set(val);
        return val;
    }

    @Override
    public TokenRateDto getTokenRate() {
        int seconds = getSecondsPerToken();
        return TokenRateDto.builder()
                .secondsPerToken(seconds)
                .description(String.format("1 Token = %d giây (tương đương %.1f phút) video trích xuất AI", seconds, seconds / 60.0))
                .build();
    }

    @Override
    @Transactional
    public TokenRateDto setSecondsPerToken(int seconds) {
        if (seconds < 1) {
            seconds = 1;
        }

        final int finalSeconds = seconds;
        SystemSetting setting = settingRepository.findBySettingKey(KEY_SECONDS_PER_TOKEN)
                .orElseGet(() -> SystemSetting.builder()
                        .settingKey(KEY_SECONDS_PER_TOKEN)
                        .description("Thời lượng video cho 1 Token AI tính bằng giây")
                        .build());

        setting.setSettingValue(String.valueOf(finalSeconds));
        settingRepository.save(setting);
        cachedSecondsPerToken.set(finalSeconds);

        log.info("Admin updated SECONDS_PER_TOKEN to {}s", finalSeconds);
        return getTokenRate();
    }

    @Override
    public int calculateTokensRequired(int durationSeconds) {
        int rate = getSecondsPerToken();
        if (rate <= 0) {
            rate = DEFAULT_SECONDS_PER_TOKEN;
        }
        if (durationSeconds <= 0) {
            return 1;
        }
        return Math.max(1, (int) Math.ceil((double) durationSeconds / rate));
    }
}
