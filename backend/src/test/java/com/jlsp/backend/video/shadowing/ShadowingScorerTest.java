package com.jlsp.backend.video.shadowing;

import com.jlsp.backend.dictionary.service.DictionaryService;
import com.jlsp.backend.video.shadowing.ShadowingScorer.Result;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ShadowingScorerTest {

    private static ShadowingScorer scorer;

    @BeforeAll
    static void setUp() {
        scorer = new ShadowingScorer(new KanaNormalizer(new DictionaryService()));
    }

    private static final String LINE = "私の名前はロックです。";

    @Test
    void identicalSentenceScores100() {
        Result r = scorer.score(LINE, "私の名前はロックです");
        assertThat(r.score()).isEqualTo(100);
        assertThat(r.level()).isEqualTo("EXCELLENT");
        assertThat(r.words()).allMatch(ShadowingScorer.WordResult::correct);
    }

    @Test
    void kanaAndKanjiAreEquivalent() {
        assertThat(scorer.score("朝食を用意しているのだろう。", "ちょうしょくをよういしているのだろう").score()).isEqualTo(100);
    }

    @Test
    void punctuationAndSpacesAreIgnored() {
        assertThat(scorer.score("ほら、さっさと出したまえ。", "ほら さっさと 出したまえ").score()).isEqualTo(100);
    }

    @Test
    void emptyRecognitionScoresZero() {
        Result r = scorer.score(LINE, "");
        assertThat(r.score()).isZero();
        assertThat(r.level()).isEqualTo("TRY_AGAIN");
        assertThat(r.words().stream().filter(w -> !w.text().equals("。"))).noneMatch(ShadowingScorer.WordResult::correct);
    }

    @Test
    void oneWrongWordLowersScoreAndIsFlagged() {
        Result r = scorer.score(LINE, "私の名前はジョンです");
        assertThat(r.score()).isBetween(30, 85);
        assertThat(r.words().stream().filter(w -> !w.correct()).map(ShadowingScorer.WordResult::text))
                .contains("ロック");
        assertThat(r.words().stream().filter(w -> w.text().equals("名前")).findFirst().get().correct()).isTrue();
    }

    @Test
    void missingHalfOfTheSentenceGetsAboutHalf() {
        Result r = scorer.score("私はまたラボに戻らなくてはならないんだ", "私はまたラボに");
        assertThat(r.score()).isBetween(25, 60);
    }

    @Test
    void unrelatedSpeechScoresLow() {
        assertThat(scorer.score(LINE, "hello world").score()).isLessThan(20);
    }

    @Test
    void levelsFollowThresholds() {
        assertThat(ShadowingScorer.levelFor(85)).isEqualTo("EXCELLENT");
        assertThat(ShadowingScorer.levelFor(84)).isEqualTo("GOOD");
        assertThat(ShadowingScorer.levelFor(70)).isEqualTo("GOOD");
        assertThat(ShadowingScorer.levelFor(50)).isEqualTo("FAIR");
        assertThat(ShadowingScorer.levelFor(49)).isEqualTo("TRY_AGAIN");
    }
}
