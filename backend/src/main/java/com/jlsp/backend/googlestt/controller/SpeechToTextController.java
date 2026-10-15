package com.jlsp.backend.googlestt.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import com.jlsp.backend.googlestt.dto.response.ScriptSegment;
import com.jlsp.backend.googlestt.dto.response.TranscriptionStatusResponse;
import com.jlsp.backend.googlestt.dto.response.TranscriptionSubmitResponse;
import com.jlsp.backend.googlestt.service.impl.SpeechToTextService;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/speech")
public class SpeechToTextController {

    private final SpeechToTextService speechToTextService;

    public SpeechToTextController(SpeechToTextService speechToTextService) {
        this.speechToTextService = speechToTextService;
    }

    @PostMapping("/transcribe")
    public ResponseEntity<TranscriptionSubmitResponse> submitTranscription(@RequestParam("file") MultipartFile file) {
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().build();
        }

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
