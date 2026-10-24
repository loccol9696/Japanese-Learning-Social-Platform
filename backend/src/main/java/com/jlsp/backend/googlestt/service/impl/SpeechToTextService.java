package com.jlsp.backend.googlestt.service.impl;

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
import com.jlsp.backend.googlestt.service.JaViTranslator;
import com.jlsp.backend.googlestt.service.SubtitleSplitter;

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

    private static final SubtitleSplitter SUBTITLE_SPLITTER = new SubtitleSplitter();

    private final VocalIsolationService vocalIsolationService;
    private final SpeechClient speechClient;
    private final Storage storage;

    @Value("${gcp.storage.bucket-name}")
    private String bucketName;

    private static final Logger log = LoggerFactory.getLogger(SpeechToTextService.class);

    // Lưu trạng thái và kết quả task trong RAM
    private final Map<String, String> taskStatusMap = new ConcurrentHashMap<>();
    private final Map<String, List<ScriptSegment>> taskResultMap = new ConcurrentHashMap<>();

    private final JaViTranslator translator;

    public SpeechToTextService(
            VocalIsolationService vocalIsolationService,
            JaViTranslator translator,
            ObjectProvider<SpeechClient> speechClientProvider,
            ObjectProvider<Storage> storageProvider) {

        this.translator = translator;
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
            throw new IllegalStateException("GCP Speech/Storage service is not available. Please check credentials.");
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

            // System.out.println("========== BẮT ĐẦU DUYỆT KẾT QUẢ GOOGLE ==========");
            // System.out.println("Tổng số results: " + response.getResultsList().size());

            for (SpeechRecognitionResult result : response.getResultsList()) {
                if (result.getAlternativesCount() == 0)
                    continue;

                SpeechRecognitionAlternative alternative = result.getAlternatives(0);
                List<WordInfo> words = alternative.getWordsList();

                if (!words.isEmpty()) {
                    if (segments.isEmpty()) {
                        // Ghi lại định dạng từ Google trả về để dễ chỉnh việc tách câu.
                        log.info("STT mẫu: \"{}\" - các từ đầu: {}", alternative.getTranscript(),
                                words.stream().limit(8).map(WordInfo::getWord).toList());
                    }

                    List<SubtitleSplitter.TimedWord> timedWords = new ArrayList<>();
                    for (WordInfo w : words) {
                        timedWords.add(new SubtitleSplitter.TimedWord(
                                w.getWord(), toSeconds(w.getStartTime()), toSeconds(w.getEndTime())));
                    }
                    double start = timedWords.get(0).start();
                    double end = timedWords.get(timedWords.size() - 1).end();

                    // Google hay gộp nhiều câu vào một kết quả: tách thành các câu ngắn, dịch từng câu.
                    for (SubtitleSplitter.Piece piece : SUBTITLE_SPLITTER.split(
                            alternative.getTranscript(), timedWords, start, end)) {
                        segments.add(ScriptSegment.builder()
                                .startTime(piece.start())
                                .endTime(piece.end())
                                .text(piece.text())
                                .translatedText(translator.translate(piece.text()))
                                .build());
                    }
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
}
