package com.jlsp.backend.video.shadowing;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.response.ShadowingLineScoreResponse;
import com.jlsp.backend.video.dto.response.ShadowingSummaryResponse;
import com.jlsp.backend.video.entity.ShadowingLineAttempt;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.ShadowingLineAttemptRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.service.impl.SubtitleResplitService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/** Chấm và lưu từng lượt luyện nói theo dòng phụ đề của video. */
@Service
public class ShadowingLineService {

    private final VideoRepository videoRepository;
    private final UserRepository userRepository;
    private final ShadowingLineAttemptRepository attemptRepository;
    private final ShadowingScorer scorer;
    private final com.jlsp.backend.streak.service.StreakService streakService;
    private final ObjectMapper mapper = new ObjectMapper();

    public ShadowingLineService(VideoRepository videoRepository, UserRepository userRepository,
            ShadowingLineAttemptRepository attemptRepository, KanaNormalizer normalizer,
            com.jlsp.backend.streak.service.StreakService streakService) {
        this.streakService = streakService;
        this.videoRepository = videoRepository;
        this.userRepository = userRepository;
        this.attemptRepository = attemptRepository;
        this.scorer = new ShadowingScorer(normalizer);
    }

    @Transactional
    public ShadowingLineScoreResponse scoreLine(Long videoId, Long userId, int lineIndex, String recognizedText) {
        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new ResourceNotFoundException("Video", "id", videoId));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));

        List<String> lines = subtitleLines(video.getSubtitles());
        if (lineIndex < 0 || lineIndex >= lines.size()) {
            throw new AppException(400, "Dòng phụ đề không tồn tại");
        }
        String expected = lines.get(lineIndex);
        String spoken = recognizedText == null ? "" : recognizedText.trim();

        ShadowingScorer.Result result = scorer.score(expected, spoken);

        attemptRepository.save(ShadowingLineAttempt.builder()
                .user(user)
                .video(video)
                .lineIndex(lineIndex)
                .expectedText(expected)
                .recognizedText(spoken)
                .score(result.score())
                .build());
        streakService.recordActivity(userId);

        int best = result.score();
        for (Object[] row : attemptRepository.summarize(userId, videoId)) {
            if (((Number) row[0]).intValue() == lineIndex) {
                best = ((Number) row[1]).intValue();
            }
        }

        return ShadowingLineScoreResponse.builder()
                .lineIndex(lineIndex)
                .expectedText(expected)
                .recognizedText(spoken)
                .score(result.score())
                .level(result.level())
                .bestScore(best)
                .words(result.words().stream()
                        .map(w -> new ShadowingLineScoreResponse.Word(w.text(), w.correct()))
                        .toList())
                .build();
    }

    @Transactional(readOnly = true)
    public ShadowingSummaryResponse summary(Long videoId, Long userId) {
        if (!videoRepository.existsById(videoId)) {
            throw new ResourceNotFoundException("Video", "id", videoId);
        }
        List<ShadowingSummaryResponse.Line> lines = new ArrayList<>();
        int sum = 0;
        for (Object[] row : attemptRepository.summarize(userId, videoId)) {
            int best = ((Number) row[1]).intValue();
            lines.add(new ShadowingSummaryResponse.Line(((Number) row[0]).intValue(), best,
                    ((Number) row[2]).intValue()));
            sum += best;
        }
        return ShadowingSummaryResponse.builder()
                .lines(lines)
                .practicedLines(lines.size())
                .averageScore(lines.isEmpty() ? 0 : Math.round((float) sum / lines.size()))
                .build();
    }

    /**
     * Danh sách câu tiếng Nhật theo đúng cách app hiển thị: bỏ dòng rỗng hoặc có end <= start,
     * để chỉ số dòng ở server và ở app trùng nhau.
     */
    List<String> subtitleLines(String subtitlesJson) {
        List<String> lines = new ArrayList<>();
        if (subtitlesJson == null || subtitlesJson.isBlank()) {
            return lines;
        }
        try {
            JsonNode root = mapper.readTree(subtitlesJson);
            if (!root.isArray()) {
                return lines;
            }
            for (JsonNode cue : root) {
                String text = cue.path("text").asText("").trim();
                double start = SubtitleResplitService.parseSeconds(cue.path("start"));
                double end = SubtitleResplitService.parseSeconds(cue.path("end"));
                if (!text.isEmpty() && end > start) {
                    lines.add(text);
                }
            }
        } catch (Exception e) {
            return new ArrayList<>();
        }
        return lines;
    }
}
