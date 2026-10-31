package com.jlsp.backend.video.service;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Quy tắc chuẩn hoá hashtag để "#Anime", "#anime" và "＃ａｎｉｍｅ" là cùng một thẻ.
 * Giữ nguyên dấu tiếng Việt khi lưu; so khớp không dấu do truy vấn đảm nhận.
 */
public final class HashtagRules {

    public static final int MAX_LENGTH = 30;

    /** Chữ cái, dấu kết hợp, chữ số và "_" của mọi ngôn ngữ (gồm kana, kanji). */
    private static final Pattern VALID = Pattern.compile("[\\p{L}\\p{M}\\p{N}_]{1," + MAX_LENGTH + "}");

    private HashtagRules() {
    }

    /** Bỏ "#" đầu, gộp ký tự toàn khổ và viết thường. Không kiểm tra tính hợp lệ. */
    public static String normalize(String raw) {
        if (raw == null) {
            return "";
        }
        String text = Normalizer.normalize(raw, Normalizer.Form.NFKC).trim();
        int start = 0;
        while (start < text.length() && text.charAt(start) == '#') {
            start++;
        }
        return text.substring(start).toLowerCase(Locale.ROOT);
    }

    /** {@code normalized} phải là kết quả của {@link #normalize(String)}. */
    public static boolean isValid(String normalized) {
        return normalized != null && VALID.matcher(normalized).matches();
    }
}
