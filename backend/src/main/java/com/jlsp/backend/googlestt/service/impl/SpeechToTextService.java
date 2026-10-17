package com.jlsp.backend.googlestt.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.gax.longrunning.OperationFuture;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.speech.v1.*;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import com.google.protobuf.Duration;
import com.jlsp.backend.googlestt.dto.response.ScriptSegment;
import com.jlsp.backend.googlestt.service.SpeechToTextServiceIntf;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ResourceLoader;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.util.UriComponents;
import org.springframework.web.util.UriComponentsBuilder;

import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;

@Service
public class SpeechToTextService implements SpeechToTextServiceIntf {

    private final VocalIsolationService vocalIsolationService;
    private final SpeechClient speechClient;
    private final Storage storage;

    @Value("${gcp.storage.bucket-name}")
    private String bucketName;

    // Lưu trạng thái và kết quả task trong RAM
    private final Map<String, String> taskStatusMap = new ConcurrentHashMap<>();
    private final Map<String, List<ScriptSegment>> taskResultMap = new ConcurrentHashMap<>();

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public SpeechToTextService(
            VocalIsolationService vocalIsolationService,
            org.springframework.beans.factory.ObjectProvider<SpeechClient> speechClientProvider,
            ResourceLoader resourceLoader,
            @Value("${gcp.speech.credentials-path}") String credentialsPath) {
        this.vocalIsolationService = vocalIsolationService;
        this.speechClient = speechClientProvider.getIfAvailable();

        Storage storageInstance = null;
        try {
            org.springframework.core.io.Resource res = resourceLoader.getResource(credentialsPath);
            if (res.exists()) {
                try (InputStream credentialsStream = res.getInputStream()) {
                    GoogleCredentials credentials = GoogleCredentials.fromStream(credentialsStream);
                    storageInstance = StorageOptions.newBuilder()
                            .setCredentials(credentials)
                            .build()
                            .getService();
                }
            }
        } catch (Exception ignored) {
        }
        this.storage = storageInstance;
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

    public String getStatus(String taskId) {
        return taskStatusMap.getOrDefault(taskId, "NOT_FOUND");
    }

    public List<ScriptSegment> getResult(String taskId) {
        return taskResultMap.get(taskId);
    }

    public List<ScriptSegment> transcribeAudioWithTimestamps(MultipartFile file)
            throws IOException, ExecutionException, InterruptedException, Exception {
        // Đổi đuôi file sang .mp3 và contentType sang audio/mpeg
        byte[] cleanVocalBytes = vocalIsolationService.separateVocals(file.getBytes());

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

            // System.out.println("========== BẮT ĐẦU DUYỆT KẾT QUẢ GOOGLE ==========");
            // System.out.println("Tổng số results: " + response.getResultsList().size());

            for (SpeechRecognitionResult result : response.getResultsList()) {
                if (result.getAlternativesCount() == 0)
                    continue;

                SpeechRecognitionAlternative alternative = result.getAlternatives(0);
                List<WordInfo> words = alternative.getWordsList();

                // System.out.println("-> Text: " + alternative.getTranscript());
                // System.out.println("-> Words count: " + words.size());
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

            // System.out.println("TỔNG SỐ SEGMENTS TẠO RA: " + segments.size());
            // System.out.println("==================================================");

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
            UriComponentsBuilder url = UriComponentsBuilder
                    .fromUriString("https://translate.googleapis.com/translate_a/single")
                    .queryParam("client", "gtx")
                    .queryParam("sl", "ja")
                    .queryParam("tl", "vi")
                    .queryParam("dt", "t") // chỉ trả về text
                    .queryParam("q", japaneseText);

            String rawResponse = restTemplate.getForObject(url.toUriString(), String.class);
            JsonNode root = objectMapper.readTree(rawResponse);

            StringBuilder translated = new StringBuilder();

            if (root.isArray() && root.size() > 0 && root.get(0).isArray()) {
                for (JsonNode item : root.get(0)) {
                    if (item.isArray() && item.size() > 0) {
                        translated.append(item.get(0).asText());
                    }
                }
            }
            return translated.toString().trim();
        } catch (Exception e) {
            System.err.println("Lỗi dịch câu: " + japaneseText + " -> " + e.getMessage());
            return "";
        }
    }
}