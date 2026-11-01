package com.jlsp.backend.dictionary.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Một từ/token trong câu phụ đề sau khi tách từ.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenResponse {
    /** Dạng xuất hiện trong câu, ví dụ 戻らなくて */
    private String surface;
    /** Dạng từ điển, ví dụ 戻る */
    private String baseForm;
    /** Cách đọc hiragana của dạng xuất hiện (rỗng nếu không biết) */
    private String reading;
    /** Từ loại cấp 1 theo IPADIC, ví dụ 名詞, 動詞 */
    private String partOfSpeech;
    /** true nếu là từ có nghĩa nên cho tra (không phải trợ từ, dấu câu...) */
    private boolean lookupable;
}
