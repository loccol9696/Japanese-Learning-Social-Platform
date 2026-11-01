package com.jlsp.backend.ai.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Một mẫu ngữ pháp xuất hiện trong một câu của subtitle.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class GrammarPoint {
    /** Mẫu ngữ pháp, ví dụ: 〜ている */
    private String pattern;
    /** Đoạn văn bản thực tế khớp mẫu trong câu, ví dụ: 食べている */
    private String matchedText;
    /** Cấp độ JLPT: N5..N1 */
    private String jlptLevel;
    /** Nghĩa tiếng Việt */
    private String meaning;
    /** Giải thích ngắn gọn bằng tiếng Việt */
    private String explanation;
}

