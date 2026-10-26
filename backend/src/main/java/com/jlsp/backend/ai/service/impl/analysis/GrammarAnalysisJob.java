package com.jlsp.backend.ai.service.impl.analysis;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.dto.response.SegmentGrammarAnalysis;
import com.jlsp.backend.ai.service.GrammarAnalysisServiceIntf;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.event.SubtitlesUpdatedEvent;
import com.jlsp.backend.video.repository.VideoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.List;

/**
 * Chạy nền: đọc subtitles (List&lt;ScriptSegment&gt; có timestamp) của video,
 * gọi AI phân tích ngữ pháp và lưu vào cột videos.grammar_analysis.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GrammarAnalysisJob {

    private final VideoRepository videoRepository;
    private final GrammarAnalysisServiceIntf grammarAnalysisService;

    private final ObjectMapper objectMapper = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    /** Chỉ chạy sau khi transaction lưu subtitles đã commit để đọc được dữ liệu mới. */
    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onSubtitlesUpdated(SubtitlesUpdatedEvent event) {
        analyzeAndSave(event.videoId());
    }

    public void analyzeAndSave(Long videoId) {
        Video video = videoRepository.findById(videoId).orElse(null);
        if (video == null || video.getSubtitles() == null || video.getSubtitles().isBlank()) {
            return;
        }
        String subtitles = video.getSubtitles();

        try {
            List<ScriptSegment> segments = objectMapper.readValue(subtitles, new TypeReference<>() {});
            if (segments.isEmpty()) {
                return;
            }

            log.info("Bắt đầu phân tích ngữ pháp video {} ({} segments)", videoId, segments.size());
            List<SegmentGrammarAnalysis> analysis = grammarAnalysisService.analyze(segments);

            int updated = videoRepository.updateGrammarAnalysisIfSubtitlesUnchanged(
                    videoId, subtitles, objectMapper.writeValueAsString(analysis));
            if (updated == 0) {
                log.info("Subtitles của video {} đã thay đổi trong lúc phân tích -> bỏ qua kết quả cũ", videoId);
            } else {
                log.info("Đã lưu phân tích ngữ pháp cho video {}", videoId);
            }
        } catch (Exception e) {
            log.error("Phân tích ngữ pháp thất bại cho video {}", videoId, e);
        }
    }
}

