package com.jlsp.backend.googlestt.service;

import com.google.api.gax.longrunning.OperationFuture;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.speech.v1.*;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import com.google.protobuf.Duration;
import com.jlsp.backend.googlestt.dto.response.ScriptSegment;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ResourceLoader;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;

import com.jlsp.backend.googlestt.service.interface.SpeechToTextServiceIntf;

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

    public SpeechToTextService(
            VocalIsolationService vocalIsolationService,
            SpeechClient speechClient,
            ResourceLoader resourceLoader,
            @Value("${gcp.speech.credentials-path}") String credentialsPath) throws IOException {
        this.vocalIsolationService = vocalIsolationService;
        this.speechClient = speechClient;

        // Đọc file credentials từ path trong application.properties (hỗ trợ cả
        // classpath: lẫn file path tuyệt đối)
        InputStream credentialsStream = resourceLoader.getResource(credentialsPath).getInputStream();
        GoogleCredentials credentials = GoogleCredentials.fromStream(credentialsStream);

        // Khởi tạo Storage với đúng credentials đó
        this.storage = StorageOptions.newBuilder()
                .setCredentials(credentials)
                .build()
                .getService();
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

            System.out.println("========== BẮT ĐẦU DUYỆT KẾT QUẢ GOOGLE ==========");
            System.out.println("Tổng số results: " + response.getResultsList().size());

            for (SpeechRecognitionResult result : response.getResultsList()) {
                if (result.getAlternativesCount() == 0)
                    continue;

                SpeechRecognitionAlternative alternative = result.getAlternatives(0);
                List<WordInfo> words = alternative.getWordsList();

                System.out.println("-> Text: " + alternative.getTranscript());
                System.out.println("-> Words count: " + words.size());

                // CÁCH LẤY TRỰC TIẾP KHÔNG SỢ BỊ LỌC MẤT:
                if (!words.isEmpty()) {
                    WordInfo firstWord = words.get(0);
                    WordInfo lastWord = words.get(words.size() - 1);

                    double start = toSeconds(firstWord.getStartTime());
                    double end = toSeconds(lastWord.getEndTime());

                    ScriptSegment seg = ScriptSegment.builder()
                            .startTime(start)
                            .endTime(end)
                            .text(alternative.getTranscript().trim())
                            .build();

                    segments.add(seg);
                    System.out.println("   + ĐÃ THÊM SEGMENT: [" + start + "s -> " + end + "s] " + seg.getText());
                } else if (!alternative.getTranscript().isBlank()) {
                    ScriptSegment seg = ScriptSegment.builder()
                            .startTime(0.0)
                            .endTime(0.0)
                            .text(alternative.getTranscript().trim())
                            .build();
                    segments.add(seg);
                    System.out.println("   + ĐÃ THÊM SEGMENT (FALLBACK): " + seg.getText());
                }
            }

            System.out.println("TỔNG SỐ SEGMENTS TẠO RA: " + segments.size());
            System.out.println("==================================================");

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
}