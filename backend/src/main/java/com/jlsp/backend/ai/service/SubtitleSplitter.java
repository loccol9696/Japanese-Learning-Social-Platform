package com.jlsp.backend.ai.service;

import java.util.ArrayList;
import java.util.List;

/**
 * Tách một đoạn nhận dạng giọng nói dài thành nhiều câu phụ đề ngắn, giữ mốc thời gian theo từng từ.
 *
 * <p>Quy tắc: luôn cắt sau 。！？; câu còn dài hơn {@code maxChars} ký tự thì cắt tiếp ở dấu 、
 * (chọn dấu gần giữa nhất), không có dấu thì cắt ở ranh giới từ gần giữa nhất; mảnh quá ngắn
 * (dưới {@code minChars} ký tự) được gộp vào mảnh bên cạnh.
 */
public final class SubtitleSplitter {

    /** Một từ do Google trả về kèm mốc thời gian (giây). */
    public record TimedWord(String text, double start, double end) {
    }

    /** Một câu phụ đề đã tách. */
    public record Piece(String text, double start, double end) {
    }

    public static final int DEFAULT_MAX_CHARS = 22;
    public static final int DEFAULT_MIN_CHARS = 4;

    private static final String SENTENCE_END = "。！？!?．";
    private static final String CLOSING = "」』）)”\"’'";
    private static final String COMMA = "、，,";
    private static final String IGNORED = "。、，．,.！？!?「」『』（）()…・~〜：:；;\"'“”‘’ 　\t\r\n";

    private final int maxChars;
    private final int minChars;

    public SubtitleSplitter() {
        this(DEFAULT_MAX_CHARS, DEFAULT_MIN_CHARS);
    }

    public SubtitleSplitter(int maxChars, int minChars) {
        this.maxChars = maxChars;
        this.minChars = minChars;
    }

    public List<Piece> split(String transcript, List<TimedWord> words, double fallbackStart, double fallbackEnd) {
        String text = transcript == null ? "" : transcript.trim();
        List<Piece> result = new ArrayList<>();
        if (text.isEmpty()) {
            return result;
        }

        // Vị trí các ký tự "nội dung" (bỏ dấu câu, khoảng trắng) trong câu gốc.
        List<Integer> contentPos = new ArrayList<>();
        for (int i = 0; i < text.length(); i++) {
            if (IGNORED.indexOf(text.charAt(i)) < 0) {
                contentPos.add(i);
            }
        }

        // Dòng thời gian theo ký tự nội dung, nội suy đều trong từng từ.
        List<double[]> timeline = new ArrayList<>();
        List<Integer> wordStarts = new ArrayList<>();
        for (TimedWord w : words == null ? List.<TimedWord>of() : words) {
            String clean = stripReading(w.text());
            List<Character> chars = new ArrayList<>();
            for (int i = 0; i < clean.length(); i++) {
                if (IGNORED.indexOf(clean.charAt(i)) < 0) {
                    chars.add(clean.charAt(i));
                }
            }
            if (chars.isEmpty()) {
                continue;
            }
            wordStarts.add(timeline.size());
            double span = Math.max(0, w.end() - w.start());
            for (int j = 0; j < chars.size(); j++) {
                timeline.add(new double[] {
                        w.start() + span * j / chars.size(),
                        w.start() + span * (j + 1) / chars.size() });
            }
        }

        if (contentPos.isEmpty()) {
            result.add(new Piece(text, fallbackStart, fallbackEnd));
            return result;
        }
        if (timeline.isEmpty()) {
            // Không có mốc từng từ: chia đều theo số ký tự trong khoảng [fallbackStart, fallbackEnd].
            for (int i = 0; i < contentPos.size(); i++) {
                double span = fallbackEnd - fallbackStart;
                timeline.add(new double[] {
                        fallbackStart + span * i / contentPos.size(),
                        fallbackStart + span * (i + 1) / contentPos.size() });
            }
        }

        // Ranh giới từ (theo chỉ số ký tự nội dung của câu gốc) để cắt khi không có dấu.
        int nText = contentPos.size();
        int nTime = timeline.size();
        List<Integer> boundaries = new ArrayList<>();
        for (int ws : wordStarts) {
            int idx = nTime == 1 ? 0 : (int) Math.round(ws * (nText - 1.0) / (nTime - 1.0));
            if (idx > 0 && idx < nText && (boundaries.isEmpty() || boundaries.get(boundaries.size() - 1) != idx)) {
                boundaries.add(idx);
            }
        }

        // Pass 1: cắt sau mọi dấu kết câu.
        List<int[]> ranges = new ArrayList<>();
        int from = 0;
        for (int i = 0; i < text.length(); i++) {
            if (SENTENCE_END.indexOf(text.charAt(i)) >= 0) {
                int end = i + 1;
                while (end < text.length() && CLOSING.indexOf(text.charAt(end)) >= 0) {
                    end++;
                }
                if (end < text.length()) {
                    ranges.add(new int[] { from, end });
                    from = end;
                }
                i = end - 1;
            }
        }
        ranges.add(new int[] { from, text.length() });

        // Pass 2: cắt tiếp các câu còn dài.
        List<int[]> shortened = new ArrayList<>();
        for (int[] r : ranges) {
            splitLong(text, r[0], r[1], contentPos, boundaries, shortened);
        }

        // Pass 3: gộp các mảnh quá ngắn vào mảnh bên cạnh.
        List<int[]> merged = new ArrayList<>();
        for (int[] r : shortened) {
            if (!merged.isEmpty() && contentCount(contentPos, r[0], r[1]) < minChars) {
                merged.get(merged.size() - 1)[1] = r[1];
            } else if (!merged.isEmpty()
                    && contentCount(contentPos, merged.get(merged.size() - 1)[0],
                            merged.get(merged.size() - 1)[1]) < minChars) {
                merged.get(merged.size() - 1)[1] = r[1];
            } else {
                merged.add(new int[] { r[0], r[1] });
            }
        }

        for (int[] r : merged) {
            int firstContent = firstContentIndex(contentPos, r[0], r[1]);
            int lastContent = lastContentIndex(contentPos, r[0], r[1]);
            String piece = text.substring(r[0], r[1]).trim();
            if (piece.isEmpty()) {
                continue;
            }
            if (firstContent < 0) {
                // Chỉ có dấu câu: nối vào mảnh trước.
                if (!result.isEmpty()) {
                    Piece prev = result.remove(result.size() - 1);
                    result.add(new Piece(prev.text() + piece, prev.start(), prev.end()));
                }
                continue;
            }
            double start = timeline.get(toTimeline(firstContent, nText, nTime))[0];
            double end = timeline.get(toTimeline(lastContent, nText, nTime))[1];
            result.add(new Piece(piece, start, Math.max(start, end)));
        }
        return result;
    }

    private void splitLong(String text, int s, int e, List<Integer> contentPos, List<Integer> boundaries,
            List<int[]> out) {
        int count = contentCount(contentPos, s, e);
        if (count <= maxChars) {
            out.add(new int[] { s, e });
            return;
        }

        int firstIdx = firstContentIndex(contentPos, s, e);
        int mid = firstIdx + count / 2;

        // Ưu tiên cắt sau dấu phẩy gần giữa nhất.
        int bestCut = -1;
        int bestDist = Integer.MAX_VALUE;
        for (int i = s; i < e - 1; i++) {
            if (COMMA.indexOf(text.charAt(i)) >= 0) {
                int cut = i + 1;
                int idxAtCut = firstContentIndex(contentPos, cut, e);
                if (idxAtCut < 0 || contentCount(contentPos, s, cut) == 0) {
                    continue;
                }
                int dist = Math.abs(idxAtCut - mid);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestCut = cut;
                }
            }
        }

        // Không có dấu phẩy: cắt ở ranh giới từ gần giữa nhất.
        if (bestCut < 0) {
            for (int b : boundaries) {
                if (b <= firstIdx || b >= firstIdx + count) {
                    continue;
                }
                int dist = Math.abs(b - mid);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestCut = contentPos.get(b);
                }
            }
        }

        if (bestCut <= s || bestCut >= e) {
            out.add(new int[] { s, e });
            return;
        }
        splitLong(text, s, bestCut, contentPos, boundaries, out);
        splitLong(text, bestCut, e, contentPos, boundaries, out);
    }

    /** Một số mô hình trả từ dạng "私|わたし": chỉ lấy phần chữ viết. */
    private static String stripReading(String word) {
        if (word == null) {
            return "";
        }
        int bar = word.indexOf('|');
        return bar >= 0 ? word.substring(0, bar) : word;
    }

    private static int toTimeline(int textIdx, int nText, int nTime) {
        if (nText == nTime || nText <= 1) {
            return Math.min(textIdx, nTime - 1);
        }
        return (int) Math.min(nTime - 1, Math.round(textIdx * (nTime - 1.0) / (nText - 1.0)));
    }

    private static int contentCount(List<Integer> contentPos, int s, int e) {
        int last = lastContentIndex(contentPos, s, e);
        int first = firstContentIndex(contentPos, s, e);
        return first < 0 ? 0 : last - first + 1;
    }

    private static int firstContentIndex(List<Integer> contentPos, int s, int e) {
        for (int i = 0; i < contentPos.size(); i++) {
            int p = contentPos.get(i);
            if (p >= e) {
                return -1;
            }
            if (p >= s) {
                return i;
            }
        }
        return -1;
    }

    private static int lastContentIndex(List<Integer> contentPos, int s, int e) {
        for (int i = contentPos.size() - 1; i >= 0; i--) {
            int p = contentPos.get(i);
            if (p < s) {
                return -1;
            }
            if (p < e) {
                return i;
            }
        }
        return -1;
    }
}
