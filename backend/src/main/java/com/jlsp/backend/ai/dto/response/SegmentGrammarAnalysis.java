package com.jlsp.backend.ai.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

/**
 * Kết quả phân tích ngữ pháp cho một segment subtitle.
 * Timestamp được copy từ ScriptSegment (không lấy từ AI) để frontend
 * có thể highlight đúng thời điểm trong video.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class SegmentGrammarAnalysis {
    /** Vị trí của segment trong mảng subtitles */
    private int index;
    private double startTime;
    private double endTime;
    private String text;
    private List<GrammarPoint> grammarPoints;
}

