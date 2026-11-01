package com.jlsp.backend.video.shadowing;

import com.jlsp.backend.dictionary.dto.TokenResponse;
import com.jlsp.backend.dictionary.service.DictionaryService;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Đổi câu tiếng Nhật (kanji + kana) về chuỗi hiragana không dấu câu để so sánh cách đọc,
 * nhờ vậy "朝食" và "ちょうしょく" được coi là giống nhau.
 */
@Component
public class KanaNormalizer {

    /** Một từ trong câu cùng cách đọc đã chuẩn hóa (rỗng nếu là dấu câu). */
    public record Token(String surface, String kana) {
    }

    private static final String IGNORED = "。、，．,.！？!?「」『』（）()…・~〜：:；;\"'“”‘’ 　\t\r\n";

    private final DictionaryService dictionary;

    public KanaNormalizer(DictionaryService dictionary) {
        this.dictionary = dictionary;
    }

    public List<Token> tokens(String text) {
        List<Token> result = new ArrayList<>();
        if (text == null || text.isBlank()) {
            return result;
        }
        for (TokenResponse t : dictionary.tokenize(text)) {
            String source = t.getReading() != null && !t.getReading().isBlank() ? t.getReading() : t.getSurface();
            result.add(new Token(t.getSurface(), clean(source)));
        }
        return result;
    }

    public String kana(String text) {
        StringBuilder sb = new StringBuilder();
        for (Token t : tokens(text)) {
            sb.append(t.kana());
        }
        return sb.toString();
    }

    /** Bỏ dấu câu và khoảng trắng, đổi katakana sang hiragana, chữ Latin về chữ thường. */
    static String clean(String s) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (IGNORED.indexOf(c) >= 0) {
                continue;
            }
            if (c >= 'ァ' && c <= 'ヶ') {
                c = (char) (c - 0x60);
            }
            sb.append(Character.toLowerCase(c));
        }
        return sb.toString();
    }
}
