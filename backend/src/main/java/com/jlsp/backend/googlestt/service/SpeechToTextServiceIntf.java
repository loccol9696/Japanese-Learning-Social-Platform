package com.jlsp.backend.googlestt.service;

import com.jlsp.backend.googlestt.dto.response.ScriptSegment;
import org.springframework.scheduling.annotation.Async;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.concurrent.ExecutionException;

public interface SpeechToTextServiceIntf {

    @Async
    void processAudioAsync(String taskId, MultipartFile file);

    void processAudioAsync(String taskId, byte[] fileBytes, String filename);

    String getStatus(String taskId);

    List<ScriptSegment> getResult(String taskId);

    List<ScriptSegment> transcribeAudioWithTimestamps(MultipartFile file)
            throws IOException, ExecutionException, InterruptedException, Exception;
}
