package com.jlsp.backend.ai.service.impl.analysis;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import com.jlsp.backend.ai.dto.response.GrammarPoint;
import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.dto.response.SegmentGrammarAnalysis;
import com.jlsp.backend.ai.service.GrammarAnalysisServiceIntf;

import java.util.ArrayList;
import java.util.List;

/**
 * Bản MOCK dùng cho môi trường dev (không gọi Gemini, không tốn quota).
 * Nhận diện ngữ pháp bằng so khớp chuỗi đơn giản để trả về dữ liệu giống thật,
 * giúp test toàn bộ luồng backend (event -> async job -> lưu DB -> API) trước khi dùng AI.
 */
@Service
@ConditionalOnProperty(prefix = "ai-analysis.mock", name = "enabled", havingValue = "true", matchIfMissing = true)
public class MockGrammarAnalysisService implements GrammarAnalysisServiceIntf {

    private static final Logger log = LoggerFactory.getLogger(MockGrammarAnalysisService.class);

    /** Bộ quy tắc mock: chuỗi cần tìm -> thông tin ngữ pháp. Đặt mẫu dài trước mẫu ngắn. */
    private record Rule(String keyword, String pattern, String jlptLevel, String meaning, String explanation) {}

    private static final List<Rule> RULES = List.of(
            new Rule("なければなりません", "〜なければならない", "N4", "phải làm gì",
                    "Diễn tả nghĩa vụ, bắt buộc phải làm."),
            new Rule("なければならない", "〜なければならない", "N4", "phải làm gì",
                    "Diễn tả nghĩa vụ, bắt buộc phải làm."),
            new Rule("かもしれません", "〜かもしれない", "N4", "có lẽ, không chừng",
                    "Diễn tả phỏng đoán với mức độ chắc chắn thấp."),
            new Rule("かもしれない", "〜かもしれない", "N4", "có lẽ, không chừng",
                    "Diễn tả phỏng đoán với mức độ chắc chắn thấp."),
            new Rule("ことができ", "〜ことができる", "N4", "có thể làm gì",
                    "V(từ điển) + ことができる: diễn tả khả năng."),
            new Rule("ようになり", "〜ようになる", "N3", "trở nên (có thể) ...",
                    "Diễn tả sự thay đổi trạng thái/thói quen theo thời gian."),
            new Rule("てください", "〜てください", "N5", "hãy (làm gì)",
                    "V-て + ください: yêu cầu/nhờ vả lịch sự."),
            new Rule("ています", "〜ている", "N5", "đang làm / trạng thái",
                    "V-て + いる: hành động đang diễn ra hoặc trạng thái kéo dài."),
            new Rule("ましょう", "〜ましょう", "N5", "cùng (làm gì) nào",
                    "Rủ rê, đề nghị cùng làm."),
            new Rule("ました", "〜ました", "N5", "đã (làm gì)",
                    "Thể quá khứ lịch sự của động từ."),
            new Rule("ません", "〜ません", "N5", "không (làm gì)",
                    "Thể phủ định lịch sự của động từ."),
            new Rule("たい", "〜たい", "N5", "muốn (làm gì)",
                    "V(bỏ ます) + たい: diễn tả mong muốn của người nói."),
            new Rule("ので", "〜ので", "N4", "vì, bởi vì",
                    "Nêu nguyên nhân/lý do một cách khách quan, mềm mại."),
            new Rule("から", "〜から", "N5", "vì / từ",
                    "Nêu lý do (chủ quan) hoặc điểm bắt đầu."),
            new Rule("ですか", "〜ですか", "N5", "... phải không?",
                    "Thêm か vào cuối câu để tạo câu hỏi."));

    /** Giả lập độ trễ của AI để test luồng async (mặc định 1.5 giây). */
    @Value("${ai-analysis.mock.delay-ms}")
    private long delayMs;

    @Override
    public List<SegmentGrammarAnalysis> analyze(List<ScriptSegment> segments) throws InterruptedException {
        log.info("[MOCK GRAMMAR] Giả lập phân tích {} segments (delay {} ms)", segments.size(), delayMs);
        if (delayMs > 0) {
            Thread.sleep(delayMs);
        }

        List<SegmentGrammarAnalysis> result = new ArrayList<>();
        for (int i = 0; i < segments.size(); i++) {
            ScriptSegment seg = segments.get(i);
            result.add(SegmentGrammarAnalysis.builder()
                    .index(i)
                    .startTime(seg.getStartTime())
                    .endTime(seg.getEndTime())
                    .text(seg.getText())
                    .grammarPoints(detect(seg.getText()))
                    .build());
        }
        log.info("[MOCK GRAMMAR] Hoàn thành");
        return result;
    }

    private List<GrammarPoint> detect(String text) {
        List<GrammarPoint> points = new ArrayList<>();
        if (text == null || text.isBlank()) {
            return points;
        }
        List<String> seenPatterns = new ArrayList<>();
        for (Rule rule : RULES) {
            if (text.contains(rule.keyword()) && !seenPatterns.contains(rule.pattern())) {
                seenPatterns.add(rule.pattern());
                points.add(GrammarPoint.builder()
                        .pattern(rule.pattern())
                        .matchedText(rule.keyword())
                        .jlptLevel(rule.jlptLevel())
                        .meaning(rule.meaning())
                        .explanation(rule.explanation())
                        .build());
            }
        }
        return points;
    }
}
