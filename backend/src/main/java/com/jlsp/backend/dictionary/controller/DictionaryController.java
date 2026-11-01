package com.jlsp.backend.dictionary.controller;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.ratelimit.ClientIpResolver;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import com.jlsp.backend.dictionary.dto.TokenResponse;
import com.jlsp.backend.dictionary.dto.WordLookupResponse;
import com.jlsp.backend.dictionary.service.DictionaryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.List;

/**
 * Tra từ trong phụ đề video.
 */
@RestController
@RequestMapping("/api/v1/dictionary")
public class DictionaryController {

    /** Tra từ gọi ra Jisho/MyMemory và endpoint công khai, nên giới hạn theo IP để khỏi bị chặn hộ. */
    static final int LOOKUPS_PER_MINUTE = 120;

    private final DictionaryService dictionaryService;
    private final RateLimiter rateLimiter;
    private final ClientIpResolver clientIpResolver;

    public DictionaryController(DictionaryService dictionaryService, RateLimiter rateLimiter,
                                ClientIpResolver clientIpResolver) {
        this.dictionaryService = dictionaryService;
        this.rateLimiter = rateLimiter;
        this.clientIpResolver = clientIpResolver;
    }

    /** GET /api/v1/dictionary/tokenize?text=... — tách câu thành từng từ. */
    @GetMapping("/tokenize")
    public ResponseEntity<ApiResponse<List<TokenResponse>>> tokenize(@RequestParam("text") String text) {
        return ResponseEntity.ok(ApiResponse.success(dictionaryService.tokenize(text)));
    }

    /** GET /api/v1/dictionary/lookup?word=... — cách đọc, nghĩa, cấp JLPT của 1 từ. */
    @GetMapping("/lookup")
    public ResponseEntity<ApiResponse<WordLookupResponse>> lookup(
            @RequestParam("word") String word, HttpServletRequest request) {
        RateLimiter.Decision decision = rateLimiter.tryAcquire(
                "dictionary-lookup:" + clientIpResolver.resolve(request), LOOKUPS_PER_MINUTE, Duration.ofMinutes(1));
        if (!decision.allowed()) {
            throw new AppException(429, "Bạn tra từ quá nhanh. Vui lòng thử lại sau "
                    + decision.retryAfterSeconds() + " giây");
        }
        return ResponseEntity.ok(ApiResponse.success(dictionaryService.lookup(word)));
    }
}
