package com.jlsp.backend.dictionary.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Kết quả tra 1 từ: dữ liệu lấy từ Jisho (cách đọc, JLPT, nghĩa tiếng Anh)
 * và MyMemory (nghĩa tiếng Việt).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WordLookupResponse {
    private String term;
    private String reading;
    /** Nghĩa tiếng Việt (có thể rỗng nếu dịch thất bại) */
    private String meaningVi;
    /** Nghĩa tiếng Anh từ Jisho (có thể rỗng) */
    private String meaningEn;
    /** N5..N1, rỗng nếu từ không thuộc danh sách JLPT */
    private String jlptLevel;
    /** Từ loại bằng tiếng Việt (Động từ, Danh từ...), rỗng nếu không rõ */
    private String partOfSpeech;
    /** false nếu không tìm được nghĩa nào */
    private boolean found;
}
