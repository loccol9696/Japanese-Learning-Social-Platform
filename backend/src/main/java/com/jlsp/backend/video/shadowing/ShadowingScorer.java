package com.jlsp.backend.video.shadowing;

import com.jlsp.backend.video.shadowing.KanaNormalizer.Token;

import java.util.ArrayList;
import java.util.List;

/**
 * Chấm điểm luyện nói nhại theo bằng cách so cách đọc (hiragana) của câu gốc với câu nhận dạng được.
 * Điểm = 100 x (1 - khoảng cách Levenshtein / độ dài câu gốc). Chỉ đánh giá việc nói đúng chữ,
 * không đo phát âm chi tiết.
 */
public final class ShadowingScorer {

    /** Một từ của câu gốc kèm cờ đọc đúng/sai. */
    public record WordResult(String text, boolean correct) {
    }

    public record Result(int score, String level, List<WordResult> words) {
    }

    public static final int EXCELLENT = 85;
    public static final int GOOD = 70;
    public static final int FAIR = 50;

    private final KanaNormalizer normalizer;

    public ShadowingScorer(KanaNormalizer normalizer) {
        this.normalizer = normalizer;
    }

    public Result score(String expectedText, String recognizedText) {
        List<Token> expectedTokens = normalizer.tokens(expectedText);
        String expected = join(expectedTokens);
        String actual = normalizer.kana(recognizedText);

        if (expected.isEmpty() || actual.isEmpty()) {
            return new Result(0, levelFor(0), wordsFor(expectedTokens, new boolean[expected.length()]));
        }

        boolean[] matched = new boolean[expected.length()];
        int distance = align(expected, actual, matched);
        int score = (int) Math.round(100.0 * (1.0 - (double) distance / expected.length()));
        score = Math.max(0, Math.min(100, score));
        return new Result(score, levelFor(score), wordsFor(expectedTokens, matched));
    }

    public static String levelFor(int score) {
        if (score >= EXCELLENT) {
            return "EXCELLENT";
        }
        if (score >= GOOD) {
            return "GOOD";
        }
        if (score >= FAIR) {
            return "FAIR";
        }
        return "TRY_AGAIN";
    }

    private static String join(List<Token> tokens) {
        StringBuilder sb = new StringBuilder();
        for (Token t : tokens) {
            sb.append(t.kana());
        }
        return sb.toString();
    }

    /** Đánh dấu ký tự câu gốc khớp trong phép căn chỉnh tối ưu và trả về khoảng cách chỉnh sửa. */
    private static int align(String expected, String actual, boolean[] matched) {
        int m = expected.length();
        int n = actual.length();
        int[][] dp = new int[m + 1][n + 1];
        for (int i = 0; i <= m; i++) {
            dp[i][0] = i;
        }
        for (int j = 0; j <= n; j++) {
            dp[0][j] = j;
        }
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                int cost = expected.charAt(i - 1) == actual.charAt(j - 1) ? 0 : 1;
                dp[i][j] = Math.min(Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1), dp[i - 1][j - 1] + cost);
            }
        }

        int i = m;
        int j = n;
        while (i > 0 && j > 0) {
            boolean same = expected.charAt(i - 1) == actual.charAt(j - 1);
            if (same && dp[i][j] == dp[i - 1][j - 1]) {
                matched[i - 1] = true;
                i--;
                j--;
            } else if (dp[i][j] == dp[i - 1][j - 1] + 1) {
                i--;
                j--;
            } else if (dp[i][j] == dp[i - 1][j] + 1) {
                i--;
            } else {
                j--;
            }
        }
        return dp[m][n];
    }

    private static List<WordResult> wordsFor(List<Token> tokens, boolean[] matched) {
        List<WordResult> words = new ArrayList<>();
        int pos = 0;
        for (Token t : tokens) {
            int len = t.kana().length();
            if (len == 0) {
                words.add(new WordResult(t.surface(), true));
                continue;
            }
            int ok = 0;
            for (int k = pos; k < pos + len && k < matched.length; k++) {
                if (matched[k]) {
                    ok++;
                }
            }
            pos += len;
            words.add(new WordResult(t.surface(), ok * 4 >= len * 3));
        }
        return words;
    }
}
