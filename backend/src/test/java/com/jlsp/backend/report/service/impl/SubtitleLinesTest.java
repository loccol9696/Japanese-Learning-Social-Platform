package com.jlsp.backend.report.service.impl;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class SubtitleLinesTest {

    private static final String SUBTITLES = """
            [{"text":"一","translation":"mot","start":0,"end":1,"romaji":"ichi"},
             {"text":"二","translatedText":"hai","start":1,"end":2}]""";

    @Test
    void readsBothTranslationFieldNames() {
        assertThat(SubtitleLines.find(SUBTITLES, 0).orElseThrow().translation()).isEqualTo("mot");
        assertThat(SubtitleLines.find(SUBTITLES, 1).orElseThrow().translation()).isEqualTo("hai");
    }

    @Test
    void missingLineOrBrokenJsonFindsNothing() {
        assertThat(SubtitleLines.find(SUBTITLES, 2)).isEmpty();
        assertThat(SubtitleLines.find(SUBTITLES, -1)).isEmpty();
        assertThat(SubtitleLines.find("không phải json", 0)).isEmpty();
        assertThat(SubtitleLines.find(null, 0)).isEmpty();
    }

    @Test
    void removingATranslationClearsBothFieldNamesAndKeepsTheRestOfTheLine() {
        String edited = SubtitleLines.withoutTranslation(SUBTITLES, 1);

        assertThat(SubtitleLines.find(edited, 1).orElseThrow().translation()).isEmpty();
        assertThat(SubtitleLines.find(edited, 1).orElseThrow().text()).isEqualTo("二");
        assertThat(SubtitleLines.find(edited, 0).orElseThrow().translation()).isEqualTo("mot");
        assertThat(edited).contains("\"romaji\":\"ichi\"");
    }

    @Test
    void removingFromAMissingLineChangesNothing() {
        assertThat(SubtitleLines.withoutTranslation(SUBTITLES, 9)).isEqualTo(SUBTITLES);
    }

    @Test
    void findsGrammarStoredInsideTheSubtitleLine() {
        String subtitles = """
                [{"text":"一","grammarPoints":[{"pattern":"〜たい","meaning":"muon"}]}]""";

        assertThat(SubtitleLines.findGrammar(subtitles, null, 0, "〜たい").orElseThrow().meaning()).isEqualTo("muon");
    }

    @Test
    void matchesGrammarByIndexOrByTextOfTheLine() {
        String byIndex = """
                [{"index":1,"grammarPoints":[{"pattern":"〜ので"}]}]""";
        String byText = """
                [{"index":7,"text":"二","grammarPoints":[{"pattern":"〜ので"}]}]""";

        assertThat(SubtitleLines.findGrammar(SUBTITLES, byIndex, 1, "〜ので")).isPresent();
        assertThat(SubtitleLines.findGrammar(SUBTITLES, byIndex, 0, "〜ので")).isEmpty();
        assertThat(SubtitleLines.findGrammar(SUBTITLES, byText, 1, "〜ので")).isPresent();
    }

    @Test
    void entryWithoutAnIndexUsesItsPosition() {
        String analysis = """
                [{"grammarPoints":[]},{"grammarPoints":[{"pattern":"〜ので"}]}]""";

        assertThat(SubtitleLines.findGrammar(SUBTITLES, analysis, 1, "〜ので")).isPresent();
    }

    @Test
    void patternlessPointIsFoundByMatchedText() {
        String analysis = """
                [{"index":0,"grammarPoints":[{"pattern":"","matchedText":"ので"}]}]""";

        assertThat(SubtitleLines.findGrammar(SUBTITLES, analysis, 0, "ので")).isPresent();
    }

    @Test
    void removingGrammarClearsItFromEveryPlaceTheClientReadsAndKeepsOtherPoints() {
        String subtitles = """
                [{"text":"一","grammarPoints":[{"pattern":"〜たい"},{"pattern":"〜ので"}]}]""";
        String analysis = """
                [{"index":0,"grammarPoints":[{"pattern":"〜たい"}]}]""";

        SubtitleLines.GrammarEdit edit = SubtitleLines.withoutGrammar(subtitles, analysis, 0, "〜たい");

        assertThat(SubtitleLines.findGrammar(edit.subtitles(), edit.grammarAnalysis(), 0, "〜たい")).isEmpty();
        assertThat(SubtitleLines.findGrammar(edit.subtitles(), edit.grammarAnalysis(), 0, "〜ので")).isPresent();
    }

    @Test
    void correctingATranslationReplacesBothFieldNamesAndLeavesOtherLinesAlone() {
        String edited = SubtitleLines.withTranslation(SUBTITLES, 1, "hai (sửa)");

        assertThat(SubtitleLines.find(edited, 1).orElseThrow().translation()).isEqualTo("hai (sửa)");
        assertThat(edited).doesNotContain("translatedText");
        assertThat(SubtitleLines.find(edited, 0).orElseThrow().translation()).isEqualTo("mot");
    }

    @Test
    void correctingGrammarUpdatesEveryPlaceTheClientReadsAndKeepsOtherPoints() {
        String subtitles = """
                [{"text":"一","grammarPoints":[
                  {"pattern":"〜たい","matchedText":"たい","meaning":"sai"},{"pattern":"〜ので","meaning":"vi"}]}]""";
        String analysis = """
                [{"index":0,"grammarPoints":[{"pattern":"〜たい","matchedText":"たい","meaning":"sai"}]}]""";

        SubtitleLines.GrammarEdit edit = SubtitleLines.withGrammar(subtitles, analysis, 0, "〜たい",
                new SubtitleLines.Grammar("〜たいです", null, "muốn", "giải thích"));

        SubtitleLines.Grammar inline = SubtitleLines.findGrammar(edit.subtitles(), null, 0, "〜たいです").orElseThrow();
        SubtitleLines.Grammar analysed = SubtitleLines
                .findGrammar("[{\"text\":\"一\"}]", edit.grammarAnalysis(), 0, "〜たいです").orElseThrow();
        assertThat(inline.meaning()).isEqualTo("muốn");
        assertThat(inline.matchedText()).isEqualTo("たい");
        assertThat(analysed.meaning()).isEqualTo("muốn");
        assertThat(SubtitleLines.findGrammar(edit.subtitles(), null, 0, "〜ので").orElseThrow().meaning())
                .isEqualTo("vi");
    }

    @Test
    void removingGrammarKeepsAMissingAnalysisMissing() {
        String subtitles = """
                [{"text":"一","grammarPoints":[{"pattern":"〜たい"}]}]""";

        assertThat(SubtitleLines.withoutGrammar(subtitles, null, 0, "〜たい").grammarAnalysis()).isNull();
    }
}
