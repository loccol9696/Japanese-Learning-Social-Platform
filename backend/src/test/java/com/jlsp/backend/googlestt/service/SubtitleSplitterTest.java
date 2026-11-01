package com.jlsp.backend.googlestt.service;

import com.jlsp.backend.ai.service.SubtitleSplitter;
import com.jlsp.backend.ai.service.SubtitleSplitter.Piece;
import com.jlsp.backend.ai.service.SubtitleSplitter.TimedWord;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class SubtitleSplitterTest {

    private final SubtitleSplitter splitter = new SubtitleSplitter();

    /** Mỗi từ dài 0.5 giây, nối liền nhau từ giây 0. */
    private static List<TimedWord> words(String... tokens) {
        List<TimedWord> list = new ArrayList<>();
        double t = 0;
        for (String token : tokens) {
            list.add(new TimedWord(token, t, t + 0.5));
            t += 0.5;
        }
        return list;
    }

    @Test
    void splitsTwoSentencesFromTheScreenshotAndKeepsWordTimes() {
        String transcript = "私はまたラボに戻らなくてはならないんだ。ほら、さっさと出したまえ。";
        List<TimedWord> words = words("私", "は", "また", "ラボ", "に", "戻ら", "なく", "て", "は", "ならない", "んだ",
                "ほら", "さっさと", "出し", "たまえ");

        List<Piece> pieces = splitter.split(transcript, words, 0, 7.5);

        assertThat(pieces).extracting(Piece::text)
                .containsExactly("私はまたラボに戻らなくてはならないんだ。", "ほら、さっさと出したまえ。");
        assertThat(pieces.get(0).start()).isEqualTo(0.0);
        assertThat(pieces.get(0).end()).isEqualTo(5.5);
        assertThat(pieces.get(1).start()).isEqualTo(5.5);
        assertThat(pieces.get(1).end()).isEqualTo(7.5);
    }

    @Test
    void shortSentenceStaysWhole() {
        List<Piece> pieces = splitter.split("こんにちは、元気ですか。", words("こんにちは", "元気", "です", "か"), 0, 2);
        assertThat(pieces).hasSize(1);
        assertThat(pieces.get(0).text()).isEqualTo("こんにちは、元気ですか。");
    }

    @Test
    void longSentenceWithoutTerminatorIsCutAtCommaNearMiddle() {
        String transcript = "今日は朝から雨が降っていたので、傘を持って学校へ行きましたが、途中で風が強くなりました";
        List<TimedWord> words = words("今日", "は", "朝", "から", "雨", "が", "降って", "いた", "ので", "傘", "を", "持って",
                "学校", "へ", "行き", "ました", "が", "途中", "で", "風", "が", "強く", "なり", "ました");

        List<Piece> pieces = splitter.split(transcript, words, 0, 12);

        assertThat(pieces.size()).isGreaterThan(1);
        assertThat(String.join("", pieces.stream().map(Piece::text).toList())).isEqualTo(transcript);
        for (Piece p : pieces) {
            assertThat(p.text().replace("、", "").length()).isLessThanOrEqualTo(24);
        }
    }

    @Test
    void longSentenceWithoutPunctuationIsCutAtWordBoundary() {
        String transcript = "私は毎日学校で日本語の勉強をして友達と一緒に楽しく遊んでいます";
        List<TimedWord> words = words("私", "は", "毎日", "学校", "で", "日本語", "の", "勉強", "を", "して", "友達", "と", "一緒",
                "に", "楽しく", "遊んで", "います");

        List<Piece> pieces = splitter.split(transcript, words, 0, 8.5);

        assertThat(pieces.size()).isGreaterThan(1);
        assertThat(String.join("", pieces.stream().map(Piece::text).toList())).isEqualTo(transcript);
        // Không cắt giữa một từ: mỗi mảnh bắt đầu đúng ranh giới từ.
        assertThat(pieces.get(1).text()).isNotEmpty();
    }

    @Test
    void tinyFragmentsAreMergedIntoNeighbours() {
        List<Piece> pieces = splitter.split("はい。私は学生です。", words("はい", "私", "は", "学生", "です"), 0, 2.5);
        assertThat(pieces).hasSize(1);
    }

    @Test
    void timesAreMonotonicAndInsideTheOriginalSpan() {
        String transcript = "私はまたラボに戻らなくてはならないんだ。ほら、さっさと出したまえ。それでは、また明日会いましょう。";
        List<Piece> pieces = splitter.split(transcript,
                words("私は", "また", "ラボに", "戻らなくては", "ならないんだ", "ほら", "さっさと", "出したまえ", "それでは", "また", "明日", "会い",
                        "ましょう"),
                0, 6.5);

        double previousEnd = 0;
        for (Piece p : pieces) {
            assertThat(p.start()).isGreaterThanOrEqualTo(previousEnd - 1e-9);
            assertThat(p.end()).isGreaterThanOrEqualTo(p.start());
            previousEnd = p.end();
        }
        assertThat(previousEnd).isLessThanOrEqualTo(6.5 + 1e-9);
    }

    @Test
    void worksWhenWordListDoesNotMatchTranscriptLength() {
        // Google đôi khi trả từ dạng "私|わたし": phần đọc phải bị bỏ khi đếm.
        List<Piece> pieces = splitter.split("私は学生です。",
                List.of(new TimedWord("私|わたし", 0, 1), new TimedWord("は", 1, 1.5), new TimedWord("学生|がくせい", 1.5, 3)),
                0, 3);
        assertThat(pieces).hasSize(1);
        assertThat(pieces.get(0).end()).isLessThanOrEqualTo(3.0);
    }

    @Test
    void fallsBackToEvenTimingWithoutWords() {
        List<Piece> pieces = splitter.split("私はまたラボに戻らなくてはならないんだ。ほら、さっさと出したまえ。", List.of(), 10, 20);
        assertThat(pieces).hasSize(2);
        assertThat(pieces.get(0).start()).isEqualTo(10.0);
        assertThat(pieces.get(1).end()).isEqualTo(20.0);
        assertThat(pieces.get(0).end()).isLessThanOrEqualTo(pieces.get(1).start() + 1e-9);
    }

    @Test
    void emptyTranscriptGivesNoPieces() {
        assertThat(splitter.split("  ", List.of(), 0, 1)).isEmpty();
        assertThat(splitter.split(null, List.of(), 0, 1)).isEmpty();
    }
}
