package com.jlsp.backend.ai.service.impl.analysis;

import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.dto.response.SegmentGrammarAnalysis;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class GrammarAnalysisTest {

    private MockGrammarAnalysisService newMock() {
        MockGrammarAnalysisService mock = new MockGrammarAnalysisService();
        ReflectionTestUtils.setField(mock, "delayMs", 0L);
        return mock;
    }

    @Test
    void keepsTimestampsAndOrder() throws Exception {
        List<ScriptSegment> segments = List.of(
                ScriptSegment.builder().startTime(0.0).endTime(2.5).text("こんにちは").build(),
                ScriptSegment.builder().startTime(2.8).endTime(5.2).text("毎日日本語を勉強しています。").build());

        List<SegmentGrammarAnalysis> result = newMock().analyze(segments);

        assertThat(result).hasSize(2);
        assertThat(result.get(0).getIndex()).isEqualTo(0);
        assertThat(result.get(1).getIndex()).isEqualTo(1);
        assertThat(result.get(1).getStartTime()).isEqualTo(2.8);
        assertThat(result.get(1).getEndTime()).isEqualTo(5.2);
        assertThat(result.get(1).getText()).isEqualTo("毎日日本語を勉強しています。");
    }

    @Test
    void detectsGrammarPoints() throws Exception {
        List<SegmentGrammarAnalysis> result = newMock().analyze(List.of(
                ScriptSegment.builder().text("雨が降っているので、家で勉強しています。").build(),
                ScriptSegment.builder().text("こんにちは").build()));

        assertThat(result.get(0).getGrammarPoints())
                .extracting("pattern")
                .contains("〜ている", "〜ので");
        assertThat(result.get(1).getGrammarPoints()).isEmpty();
    }

    @Test
    void handlesBlankText() throws Exception {
        List<SegmentGrammarAnalysis> result = newMock().analyze(List.of(
                ScriptSegment.builder().startTime(1).endTime(2).text(null).build()));

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getGrammarPoints()).isEmpty();
    }
}

