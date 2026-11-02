package com.jlsp.backend.report.service.impl;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.MissingNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Đọc và gỡ bản dịch / mẫu ngữ pháp của một câu trong JSON phụ đề của video. Câu được xác định bằng vị
 * trí trong mảng subtitles. Cách đọc khớp với client: bản dịch ở translation hoặc translatedText, ngữ
 * pháp nằm ngay trong câu hoặc trong grammarAnalysis (theo index, hoặc theo text của câu).
 */
final class SubtitleLines {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    record Line(String text, String translation) {
    }

    record Grammar(String pattern, String matchedText, String meaning, String explanation) {
    }

    record GrammarEdit(String subtitles, String grammarAnalysis) {
    }

    private SubtitleLines() {
    }

    static Optional<Line> find(String subtitles, int index) {
        JsonNode cue = cueAt(parse(subtitles), index);
        if (cue == null) {
            return Optional.empty();
        }
        return Optional.of(new Line(cue.path("text").asText(""), translationOf(cue)));
    }

    static Optional<Grammar> findGrammar(String subtitles, String grammarAnalysis, int index, String pattern) {
        for (ArrayNode points : grammarLists(parse(subtitles), parse(grammarAnalysis), index)) {
            for (JsonNode point : points) {
                if (identifierOf(point).equals(pattern)) {
                    return Optional.of(new Grammar(point.path("pattern").asText(""),
                            point.path("matchedText").asText(""), point.path("meaning").asText(""),
                            point.path("explanation").asText("")));
                }
            }
        }
        return Optional.empty();
    }

    static String withoutTranslation(String subtitles, int index) {
        return withTranslation(subtitles, index, "");
    }

    static String withScriptText(String subtitles, int index, String newText) {
        JsonNode root = parse(subtitles);
        if (cueAt(root, index) instanceof ObjectNode cue) {
            cue.put("text", newText != null ? newText.trim() : "");
            cue.remove("ruby");
            cue.remove("tokens");
            return root.toString();
        }
        return subtitles;
    }

    static String withTranslation(String subtitles, int index, String translation) {
        JsonNode root = parse(subtitles);
        if (cueAt(root, index) instanceof ObjectNode cue) {
            cue.put("translation", translation);
            cue.remove("translatedText");
            return root.toString();
        }
        return subtitles;
    }

    static GrammarEdit withoutGrammar(String subtitles, String grammarAnalysis, int index, String pattern) {
        JsonNode subtitleRoot = parse(subtitles);
        JsonNode analysisRoot = parse(grammarAnalysis);
        for (ArrayNode points : grammarLists(subtitleRoot, analysisRoot, index)) {
            for (int i = points.size() - 1; i >= 0; i--) {
                if (identifierOf(points.get(i)).equals(pattern)) {
                    points.remove(i);
                }
            }
        }
        return editOf(subtitles, subtitleRoot, grammarAnalysis, analysisRoot);
    }

    /** Sửa mẫu [pattern] ở mọi nơi client đọc; matchedText giữ nguyên để câu vẫn gạch chân đúng chỗ. */
    static GrammarEdit withGrammar(String subtitles, String grammarAnalysis, int index, String pattern,
                                   Grammar corrected) {
        JsonNode subtitleRoot = parse(subtitles);
        JsonNode analysisRoot = parse(grammarAnalysis);
        for (ArrayNode points : grammarLists(subtitleRoot, analysisRoot, index)) {
            for (JsonNode point : points) {
                if (point instanceof ObjectNode editable && identifierOf(point).equals(pattern)) {
                    editable.put("pattern", corrected.pattern());
                    editable.put("meaning", corrected.meaning());
                    editable.put("explanation", corrected.explanation());
                }
            }
        }
        return editOf(subtitles, subtitleRoot, grammarAnalysis, analysisRoot);
    }

    private static GrammarEdit editOf(String subtitles, JsonNode subtitleRoot,
                                      String grammarAnalysis, JsonNode analysisRoot) {
        return new GrammarEdit(subtitleRoot.isMissingNode() ? subtitles : subtitleRoot.toString(),
                analysisRoot.isMissingNode() ? grammarAnalysis : analysisRoot.toString());
    }

    /** Mọi danh sách mẫu ngữ pháp áp dụng cho câu; hai câu trùng chữ dùng chung lời giải thích. */
    private static List<ArrayNode> grammarLists(JsonNode subtitles, JsonNode analysis, int index) {
        List<ArrayNode> lists = new ArrayList<>();
        JsonNode cue = cueAt(subtitles, index);
        if (cue == null) {
            return lists;
        }
        if (cue.get("grammarPoints") instanceof ArrayNode inline) {
            lists.add(inline);
        }
        if (analysis.isArray()) {
            String text = cue.path("text").asText("").trim();
            for (int position = 0; position < analysis.size(); position++) {
                JsonNode entry = analysis.get(position);
                int entryIndex = entry.hasNonNull("index") ? entry.get("index").asInt() : position;
                boolean sameText = !text.isEmpty() && entry.path("text").asText("").trim().equals(text);
                if ((entryIndex == index || sameText) && entry.get("grammarPoints") instanceof ArrayNode points) {
                    lists.add(points);
                }
            }
        }
        return lists;
    }

    private static JsonNode cueAt(JsonNode root, int index) {
        return root.isArray() && index >= 0 && index < root.size() ? root.get(index) : null;
    }

    private static String translationOf(JsonNode cue) {
        JsonNode node = cue.hasNonNull("translation") ? cue.get("translation") : cue.get("translatedText");
        return node == null || node.isNull() ? "" : node.asText("");
    }

    /** Client gửi pattern, mẫu không có pattern thì gửi matchedText. */
    private static String identifierOf(JsonNode point) {
        String pattern = point.path("pattern").asText("");
        return pattern.isEmpty() ? point.path("matchedText").asText("") : pattern;
    }

    private static JsonNode parse(String json) {
        if (json == null || json.isBlank()) {
            return MissingNode.getInstance();
        }
        try {
            return MAPPER.readTree(json);
        } catch (JsonProcessingException e) {
            return MissingNode.getInstance();
        }
    }
}
