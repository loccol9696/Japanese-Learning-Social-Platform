package com.jlsp.backend.googlestt.service.impl;

import com.jlsp.backend.common.constant.ErrorCode;
import com.jlsp.backend.common.exception.AppException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.gax.longrunning.OperationFuture;
import com.google.cloud.speech.v1.*;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.protobuf.Duration;
import com.jlsp.backend.googlestt.dto.response.ScriptSegment;
import com.jlsp.backend.googlestt.service.SpeechToTextServiceIntf;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.util.UriComponentsBuilder;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;

@Service
@ConditionalOnProperty(name = "gcp.stt.enabled", havingValue = "true", matchIfMissing = true)
public class SpeechToTextService implements SpeechToTextServiceIntf {

    private final VocalIsolationService vocalIsolationService;
    private final SpeechClient speechClient;
    private final Storage storage;

    @Value("${gcp.storage.bucket-name}")
    private String bucketName;

    private static final Logger log = LoggerFactory.getLogger(SpeechToTextService.class);

    // Lưu trạng thái và kết quả task trong RAM
    private final Map<String, String> taskStatusMap = new ConcurrentHashMap<>();
    private final Map<String, List<ScriptSegment>> taskResultMap = new ConcurrentHashMap<>();

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public SpeechToTextService(
            VocalIsolationService vocalIsolationService,
            ObjectProvider<SpeechClient> speechClientProvider,
            ObjectProvider<Storage> storageProvider) {

        this.vocalIsolationService = vocalIsolationService;
        this.speechClient = speechClientProvider.getIfAvailable();
        this.storage = storageProvider.getIfAvailable();

        if (this.speechClient == null || this.storage == null) {
            log.warn("Google Cloud SpeechClient/Storage is not initialized. STT features might be disabled.");
        }
    }

    @Async
    public void processAudioAsync(String taskId, MultipartFile file) {
        try {
            taskStatusMap.put(taskId, "PROCESSING");
            List<ScriptSegment> segments = transcribeAudioWithTimestamps(file);
            taskResultMap.put(taskId, segments);
            taskStatusMap.put(taskId, "COMPLETED");
        } catch (Exception e) {
            taskStatusMap.put(taskId, "FAILED: " + e.getMessage());
        }
    }

    @Async
    @Override
    public void processAudioAsync(String taskId, byte[] fileBytes, String filename) {
        try {
            taskStatusMap.put(taskId, "PROCESSING");
            List<ScriptSegment> segments = transcribeAudioWithTimestamps(fileBytes);
            taskResultMap.put(taskId, segments);
            taskStatusMap.put(taskId, "COMPLETED");
        } catch (Exception e) {
            log.error("AI transcription thất bại cho task {}", taskId, e);
            taskStatusMap.put(taskId, "FAILED: " + e.getMessage());
        }
    }

    public String getStatus(String taskId) {
        return taskStatusMap.getOrDefault(taskId, "NOT_FOUND");
    }

    public List<ScriptSegment> getResult(String taskId) {
        return taskResultMap.get(taskId);
    }

    public List<ScriptSegment> transcribeAudioWithTimestamps(MultipartFile file)
            throws IOException, ExecutionException, InterruptedException, Exception {
        return transcribeAudioWithTimestamps(file.getBytes());
    }

    private List<ScriptSegment> transcribeAudioWithTimestamps(byte[] fileBytes)
            throws IOException, ExecutionException, InterruptedException, Exception {

        if (this.speechClient == null || this.storage == null) {
            throw new AppException(ErrorCode.SERVICE_UNAVAILABLE,
                    "GCP Speech/Storage service is not available. Please check credentials.");
        }
        // Đổi đuôi file sang .mp3 và contentType sang audio/mpeg
        byte[] cleanVocalBytes = vocalIsolationService.separateVocals(fileBytes);

        // 2. Upload file vocal mp3 sạch lên GCS
        String fileName = "audio-transcribe/" + UUID.randomUUID() + ".wav";
        BlobId blobId = BlobId.of(bucketName, fileName);
        BlobInfo blobInfo = BlobInfo.newBuilder(blobId).setContentType("audio/wav").build();
        storage.create(blobInfo, cleanVocalBytes);

        String gcsUri = String.format("gs://%s/%s", bucketName, fileName);
        try {
            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setEncoding(RecognitionConfig.AudioEncoding.LINEAR16)
                    .setLanguageCode("ja-JP")
                    .setModel("latest_long") // Sử dụng model mới nhất
                    .setAudioChannelCount(2) // Nhận diện 2 kênh nếu file là stereo
                    .setUseEnhanced(true)
                    .setEnableAutomaticPunctuation(true)
                    .setEnableWordTimeOffsets(true) // BẬT ĐO MỐC THỜI GIAN
                    .build();

            RecognitionAudio audio = RecognitionAudio.newBuilder()
                    .setUri(gcsUri)
                    .build();

            OperationFuture<LongRunningRecognizeResponse, LongRunningRecognizeMetadata> responseFuture = speechClient
                    .longRunningRecognizeAsync(config, audio);

            LongRunningRecognizeResponse response = responseFuture.get();
            List<ScriptSegment> segments = new ArrayList<>();


            for (SpeechRecognitionResult result : response.getResultsList()) {
                if (result.getAlternativesCount() == 0)
                    continue;

                SpeechRecognitionAlternative alternative = result.getAlternatives(0);
                List<WordInfo> words = alternative.getWordsList();

                if (!words.isEmpty()) {
                    WordInfo firstWord = words.get(0);
                    WordInfo lastWord = words.get(words.size() - 1);

                    double start = toSeconds(firstWord.getStartTime());
                    double end = toSeconds(lastWord.getEndTime());

                    String japaneseText = alternative.getTranscript().trim();
                    String vietnameseText = translateToVi(alternative.getTranscript().trim());

                    ScriptSegment seg = ScriptSegment.builder()
                            .startTime(start)
                            .endTime(end)
                            .text(japaneseText)
                            .translatedText(vietnameseText)
                            .build();

                    segments.add(seg);
                }
            }


            return segments;
        } finally {
            try {
                storage.delete(blobId);
            } catch (Exception ignored) {
            }
        }
    }

    private double toSeconds(Duration duration) {
        return duration.getSeconds() + (duration.getNanos() / 1_000_000_000.0);
    }

    private String translateToVi(String japaneseText) {
        if (japaneseText == null || japaneseText.isBlank()) {
            return "";
        }
        try {
            URI uri = UriComponentsBuilder.fromUriString("https://api.mymemory.translated.net/get")
                    .queryParam("q", japaneseText)
                    .queryParam("langpair", "ja|vi")
                    .queryParam("de", "minedung2005@gmail.com") // Đổi thành email hợp lệ để tăng hạn mức
                    .encode(StandardCharsets.UTF_8)
                    .build()
                    .toUri();

            String rawResponse = restTemplate.getForObject(uri, String.class);
            if (rawResponse == null || rawResponse.isBlank()) {
                return "";
            }

            JsonNode root = objectMapper.readTree(rawResponse);
            int status = root.path("responseStatus").asInt(0);

            // 200 là thành công, 429/403 là hết quota
            if (status == 200 && root.has("responseData")) {
                return root.get("responseData").path("translatedText").asText("").trim();
            } else {
                log.warn("MyMemory lỗi phản hồi mã {}: {}", status, rawResponse);
                return "";
            }
        } catch (Exception e) {
            log.error("Lỗi khi dịch tiếng Nhật sang tiếng Việt: [{}] - {}", japaneseText, e.getMessage());
            return "";
        }
    }
}