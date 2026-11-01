package com.jlsp.backend.ai.service.impl.speechtotext;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.service.SpeechToTextServiceIntf;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
@ConditionalOnProperty(name = "gcp.stt.enabled", havingValue = "false", matchIfMissing = false)
public class MockSpeechToTextService implements SpeechToTextServiceIntf {

    private static final Logger log = LoggerFactory.getLogger(MockSpeechToTextService.class);

    private final Map<String, String> taskStatusMap = new ConcurrentHashMap<>();
    private final Map<String, List<ScriptSegment>> taskResultMap = new ConcurrentHashMap<>();

    @Async
    public void processAudioAsync(String taskId, MultipartFile file) {
        processMockTask(taskId);
    }

    @Async
    @Override
    public void processAudioAsync(String taskId, byte[] fileBytes, String filename) {
        processMockTask(taskId);
    }

    private void processMockTask(String taskId) {
        log.info("[MOCK STT] Đang giả lập xử lý audio cho taskId: {}", taskId);
        taskStatusMap.put(taskId, "PROCESSING");
        try {
            // Giả lập độ trễ nhận diện 15 giây để test thoát giữa chừng / interrupt
            Thread.sleep(15_000);

            List<ScriptSegment> mockSegments = List.of(
                ScriptSegment.builder()
                    .startTime(0.0)
                    .endTime(2.5)
                    .text("こんにちは、元気ですか。")
                    .translatedText("Xin chào, bạn khỏe không?")
                    .build(),
                ScriptSegment.builder()
                    .startTime(2.8)
                    .endTime(5.2)
                    .text("日本語の勉強を始めましょう。")
                    .translatedText("Hãy cùng bắt đầu học tiếng Nhật nhé.")
                    .build()
            );

            taskResultMap.put(taskId, mockSegments);
            taskStatusMap.put(taskId, "COMPLETED");
            log.info("[MOCK STT] Hoàn thành taskId: {}", taskId);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            taskStatusMap.put(taskId, "FAILED: Giả lập bị ngắt");
        }
    }

    @Override
    public String getStatus(String taskId) {
        return taskStatusMap.getOrDefault(taskId, "NOT_FOUND");
    }

    @Override
    public List<ScriptSegment> getResult(String taskId) {
        return taskResultMap.get(taskId);
    }
}
