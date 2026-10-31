package com.jlsp.backend.ai.service.impl.analysis;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.jlsp.backend.ai.dto.response.GrammarPoint;
import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.dto.response.SegmentGrammarAnalysis;
import com.jlsp.backend.ai.service.GrammarAnalysisServiceIntf;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Phân tích ngữ pháp subtitle bằng Gemini API (Google AI Studio key).
 * Chỉ gửi index + text lên AI; timestamp được giữ nguyên ở server rồi ghép lại theo index.
 */
@Service
@ConditionalOnProperty(prefix = "ai-analysis.mock", name = "enabled", havingValue = "false", matchIfMissing = false)
public class GrammarAnalysisService implements GrammarAnalysisServiceIntf {

    private static final Logger log = LoggerFactory.getLogger(GrammarAnalysisService.class);
    private static final int BATCH_SIZE = 25;

    private static final String PROMPT_TEMPLATE = """
            Bạn là giáo viên tiếng Nhật. Với MỖI câu trong input (JSON array {"i", "text"}),
            liệt kê các mẫu ngữ pháp đáng chú ý cho người học.
            Chỉ trả về JSON array, giữ nguyên giá trị "i" của input, theo đúng cấu trúc:
            [{"i":0,"grammarPoints":[{"pattern":"〜ている","matchedText":"食べている","jlptLevel":"N5",
              "meaning":"(nghĩa tiếng Việt)","explanation":"(giải thích ngắn gọn bằng tiếng Việt)"}]}]
            - jlptLevel là một trong N5, N4, N3, N2, N1.
            - matchedText phải là chuỗi con xuất hiện trong câu.
            - Câu không có ngữ pháp đáng chú ý thì grammarPoints = [].
            Input:
            %s
            """;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final String apiKey;
    private final String baseUrl;
    private final String model;

    public GrammarAnalysisService(
            @Value("${ai-analysis.api-key}") String apiKey,
            @Value("${ai-analysis.base-url}") String baseUrl,
            @Value("${ai-analysis.model:gemini-3.8-flash}") String model) {
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
        this.model = model;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(15_000);
        factory.setReadTimeout(120_000);
        this.restTemplate = new RestTemplate(factory);
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("ai-analysis.api-key (GEMINI_API_KEY) chưa được cấu hình. Grammar analysis sẽ thất bại.");
        }
    }

    @Override
    public List<SegmentGrammarAnalysis> analyze(List<ScriptSegment> segments) throws Exception {
        // Khởi tạo kết quả từ segments -> timestamp luôn lấy từ dữ liệu gốc
        List<SegmentGrammarAnalysis> result = new ArrayList<>();
        for (int i = 0; i < segments.size(); i++) {
            ScriptSegment seg = segments.get(i);
            result.add(SegmentGrammarAnalysis.builder()
                    .index(i)
                    .startTime(seg.getStartTime())
                    .endTime(seg.getEndTime())
                    .text(seg.getText())
                    .grammarPoints(new ArrayList<>())
                    .build());
        }

        for (int from = 0; from < segments.size(); from += BATCH_SIZE) {
            int to = Math.min(from + BATCH_SIZE, segments.size());

            List<Map<String, Object>> input = new ArrayList<>();
            for (int i = from; i < to; i++) {
                String text = segments.get(i).getText();
                if (text == null || text.isBlank()) continue;
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("i", i);
                item.put("text", text);
                input.add(item);
            }
            if (input.isEmpty()) continue;

            String prompt = String.format(PROMPT_TEMPLATE, objectMapper.writeValueAsString(input));
            String json = stripMarkdownFence(callGemini(prompt));

            List<AiSegmentResult> aiResults = objectMapper.readValue(json, new TypeReference<>() {});
            for (AiSegmentResult r : aiResults) {
                // Chỉ nhận index thuộc batch hiện tại, bỏ qua nếu AI trả index lạ
                if (r.i >= from && r.i < to && r.grammarPoints != null) {
                    result.get(r.i).setGrammarPoints(r.grammarPoints);
                }
            }
        }
        return result;
    }

    /** Gọi Gemini generateContent, ép trả về JSON và trả lại phần text của response. */
    private String callGemini(String prompt) throws Exception {
        String url = String.format("%s/models/%s:generateContent", baseUrl, model);

        Map<String, Object> body = new HashMap<>();
        body.put("contents", List.of(Map.of("parts", List.of(Map.of("text", prompt)))));
        body.put("generationConfig", Map.of(
                "responseMimeType", "application/json",
                "temperature", 0.2));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("x-goog-api-key", apiKey);

        String raw = restTemplate.postForObject(url,
                new HttpEntity<>(objectMapper.writeValueAsString(body), headers), String.class);
        if (raw == null || raw.isBlank()) {
            throw new IllegalStateException("Gemini trả về response rỗng");
        }

        JsonNode parts = objectMapper.readTree(raw)
                .path("candidates").path(0).path("content").path("parts");
        StringBuilder text = new StringBuilder();
        for (JsonNode part : parts) {
            text.append(part.path("text").asText(""));
        }
        if (text.isEmpty()) {
            throw new IllegalStateException("Gemini không trả về nội dung: " + raw);
        }
        return text.toString();
    }

    private static String stripMarkdownFence(String raw) {
        String trimmed = raw == null ? "" : raw.trim();
        if (trimmed.startsWith("```")) {
            int firstNewline = trimmed.indexOf('\n');
            if (firstNewline > 0) {
                trimmed = trimmed.substring(firstNewline + 1);
            }
            if (trimmed.endsWith("```")) {
                trimmed = trimmed.substring(0, trimmed.length() - 3);
            }
        }
        return trimmed.trim();
    }

    /** Cấu trúc JSON mà Gemini trả về cho mỗi câu. */
    private static class AiSegmentResult {
        public int i;
        public List<GrammarPoint> grammarPoints;
    }
}
