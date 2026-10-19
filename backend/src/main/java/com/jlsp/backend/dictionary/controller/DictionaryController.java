package com.jlsp.backend.dictionary.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.dictionary.dto.TokenResponse;
import com.jlsp.backend.dictionary.dto.WordLookupResponse;
import com.jlsp.backend.dictionary.service.DictionaryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Tra từ trong phụ đề video.
 */
@RestController
@RequestMapping("/api/v1/dictionary")
public class DictionaryController {

    private final DictionaryService dictionaryService;

    public DictionaryController(DictionaryService dictionaryService) {
        this.dictionaryService = dictionaryService;
    }

    /** GET /api/v1/dictionary/tokenize?text=... — tách câu thành từng từ. */
    @GetMapping("/tokenize")
    public ResponseEntity<ApiResponse<List<TokenResponse>>> tokenize(@RequestParam("text") String text) {
        return ResponseEntity.ok(ApiResponse.success(dictionaryService.tokenize(text)));
    }

    /** GET /api/v1/dictionary/lookup?word=... — cách đọc, nghĩa, cấp JLPT của 1 từ. */
    @GetMapping("/lookup")
    public ResponseEntity<ApiResponse<WordLookupResponse>> lookup(@RequestParam("word") String word) {
        return ResponseEntity.ok(ApiResponse.success(dictionaryService.lookup(word)));
    }
}
