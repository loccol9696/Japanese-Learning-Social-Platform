package com.jlsp.backend.ai.service;

import org.springframework.scheduling.annotation.Async;
import org.springframework.web.multipart.MultipartFile;

import com.jlsp.backend.ai.dto.response.ScriptSegment;

import java.util.List;

public interface SpeechToTextServiceIntf {

    @Async
    void processAudioAsync(String taskId, MultipartFile file);

    void processAudioAsync(String taskId, byte[] fileBytes, String filename);

    String getStatus(String taskId);

    List<ScriptSegment> getResult(String taskId);
}
