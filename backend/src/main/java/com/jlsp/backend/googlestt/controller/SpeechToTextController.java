package com.jlsp.backend.googlestt.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import com.jlsp.backend.googlestt.dto.response.ScriptSegment;
import com.jlsp.backend.googlestt.dto.response.TranscriptionStatusResponse;
import com.jlsp.backend.googlestt.dto.response.TranscriptionSubmitResponse;
import com.jlsp.backend.googlestt.service.SpeechToTextServiceIntf;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/speech")
public class SpeechToTextController {

    private final SpeechToTextServiceIntf speechToTextService;
    private final com.jlsp.backend.subscription.service.SubscriptionService subscriptionService;
    private final com.jlsp.backend.subscription.service.SystemSettingService systemSettingService;

    public SpeechToTextController(
            SpeechToTextServiceIntf speechToTextService,
            com.jlsp.backend.subscription.service.SubscriptionService subscriptionService,
            com.jlsp.backend.subscription.service.SystemSettingService systemSettingService) {
        this.speechToTextService = speechToTextService;
        this.subscriptionService = subscriptionService;
        this.systemSettingService = systemSettingService;
    }

    @PostMapping("/transcribe")
    public ResponseEntity<TranscriptionSubmitResponse> submitTranscription(
            @RequestParam("file") MultipartFile file,
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId,
            @RequestParam(value = "duration", required = false) Integer durationSeconds) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().build();
        }

        Long userId = headerUserId != null ? headerUserId : (paramUserId != null ? paramUserId : 1L);

        // Tính toán số token theo thời lượng video (mặc định 60s / 1 token, có thể tùy chỉnh trong Admin)
        int duration = (durationSeconds != null && durationSeconds > 0) ? durationSeconds : 60;
        int tokensRequired = systemSettingService.calculateTokensRequired(duration);

        // Kiểm tra và trừ Token hạn mức theo ngày
        subscriptionService.validateAndDeductTokens(userId, tokensRequired);

        String taskId = UUID.randomUUID().toString();
        speechToTextService.processAudioAsync(taskId, file);

        TranscriptionSubmitResponse response = TranscriptionSubmitResponse.builder()
                .taskId(taskId)
                .status("PROCESSING")
                .checkUrl("/api/speech/status/" + taskId)
                .createdAt(LocalDateTime.now())
                .build();

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
    }

    @GetMapping("/status/{taskId}")
    public ResponseEntity<TranscriptionStatusResponse> checkStatus(@PathVariable String taskId) {
        String status = speechToTextService.getStatus(taskId);

        if ("NOT_FOUND".equals(status)) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(TranscriptionStatusResponse.builder()
                            .taskId(taskId)
                            .status("NOT_FOUND")
                            .errorMessage("Không tìm thấy tác vụ với ID này")
                            .build());
        }

        if (status.startsWith("FAILED")) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(TranscriptionStatusResponse.builder()
                            .taskId(taskId)
                            .status("FAILED")
                            .errorMessage(status.replace("FAILED: ", ""))
                            .build());
        }

        if ("COMPLETED".equals(status)) {
            List<ScriptSegment> segments = speechToTextService.getResult(taskId);
            return ResponseEntity.ok(TranscriptionStatusResponse.builder()
                    .taskId(taskId)
                    .status("COMPLETED")
                    .totalSegments(segments != null ? segments.size() : 0)
                    .segments(segments)
                    .build());
        }

        // Đang xử lý
        return ResponseEntity.ok(TranscriptionStatusResponse.builder()
                .taskId(taskId)
                .status("PROCESSING")
                .build());
    }
}
