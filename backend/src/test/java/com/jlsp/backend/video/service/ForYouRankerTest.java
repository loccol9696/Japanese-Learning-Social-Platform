package com.jlsp.backend.video.service;

import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class ForYouRankerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 29, 12, 0);

    private static Video video(long id, JLPTLevel level, Long topicId, long views) {
        return Video.builder()
                .id(id)
                .jlptLevel(level)
                .topic(topicId == null ? null : Topic.builder().id(topicId).build())
                .viewCount(views)
                .likeCount(0)
                .saveCount(0)
                .createdAt(NOW.minusDays(1))
                .build();
    }

    private static List<Long> ids(List<Video> videos) {
        return videos.stream().map(Video::getId).toList();
    }

    @Test
    void khopTrinhDoVaChuDeDuocXepTruocVideoKhongLienQuan() {
        Video khop = video(1, JLPTLevel.N3, 7L, 0);
        Video khongLienQuan = video(2, JLPTLevel.N1, 9L, 10_000);

        var ranked = ForYouRanker.rank(List.of(khongLienQuan, khop),
                new ForYouRanker.Preferences(JLPTLevel.N3, Set.of(7L)), NOW);

        assertThat(ids(ranked)).containsExactly(1L, 2L);
    }

    @Test
    void trinhDoLechMotBacDuocDiemThapHonDungTrinhDo() {
        assertThat(ForYouRanker.levelFit(JLPTLevel.N3, JLPTLevel.N3)).isEqualTo(1.0);
        assertThat(ForYouRanker.levelFit(JLPTLevel.N3, JLPTLevel.N4)).isEqualTo(0.5);
        assertThat(ForYouRanker.levelFit(JLPTLevel.N3, JLPTLevel.N5)).isZero();
        assertThat(ForYouRanker.levelFit(JLPTLevel.N3, null)).isEqualTo(0.3);
        assertThat(ForYouRanker.levelFit(null, JLPTLevel.N3)).isZero();
    }

    @Test
    void trongCacVideoNganhNhauThiPhoBienHonDuocXepTruoc() {
        Video it = video(1, JLPTLevel.N5, 7L, 10);
        Video nhieu = video(2, JLPTLevel.N5, 7L, 5_000);

        var ranked = ForYouRanker.rank(List.of(it, nhieu),
                new ForYouRanker.Preferences(JLPTLevel.N5, Set.of(7L)), NOW);

        assertThat(ids(ranked)).containsExactly(2L, 1L);
    }

    @Test
    void cuMoiNVideoThiChenMotVideoNgoaiSoThich() {
        List<Video> pool = new ArrayList<>();
        for (long i = 1; i <= 8; i++) {
            pool.add(video(i, JLPTLevel.N3, 7L, 100)); // khớp
        }
        pool.add(video(100, JLPTLevel.N1, 9L, 0)); // ngoài sở thích
        pool.add(video(101, JLPTLevel.N1, 9L, 0));

        var ranked = ForYouRanker.rank(pool, new ForYouRanker.Preferences(JLPTLevel.N3, Set.of(7L)), NOW);

        assertThat(ranked).hasSize(10);
        assertThat(ranked.get(ForYouRanker.EXPLORE_EVERY - 1).getId()).isIn(100L, 101L);
        assertThat(ranked.get(2 * ForYouRanker.EXPLORE_EVERY - 1).getId()).isIn(100L, 101L);
    }

    @Test
    void khongCoVideoKhopThiVanTraDuMoiVideoMotLan() {
        List<Video> pool = List.of(video(1, JLPTLevel.N1, 9L, 0), video(2, JLPTLevel.N1, 9L, 0),
                video(3, JLPTLevel.N1, 9L, 0));

        var ranked = ForYouRanker.rank(pool, new ForYouRanker.Preferences(JLPTLevel.N5, Set.of(7L)), NOW);

        assertThat(ids(ranked)).containsExactlyInAnyOrder(1L, 2L, 3L);
    }

    @Test
    void thuTuOnDinhDeCacTrangLienTiepKhongLapHaySot() {
        List<Video> pool = new ArrayList<>();
        for (long i = 1; i <= 30; i++) {
            pool.add(video(i, i % 2 == 0 ? JLPTLevel.N3 : JLPTLevel.N1, i % 3 == 0 ? 7L : 9L, i));
        }
        var prefs = new ForYouRanker.Preferences(JLPTLevel.N3, Set.of(7L));

        var first = ForYouRanker.rank(pool, prefs, NOW);
        List<Video> shuffled = new ArrayList<>(pool);
        java.util.Collections.reverse(shuffled);
        var again = ForYouRanker.rank(shuffled, prefs, NOW);

        assertThat(ids(again)).isEqualTo(ids(first));
        assertThat(ids(first)).doesNotHaveDuplicates().hasSize(30);
    }

    @Test
    void danhSachRongTraRong() {
        assertThat(ForYouRanker.rank(List.of(), new ForYouRanker.Preferences(JLPTLevel.N5, Set.of()), NOW))
                .isEmpty();
    }

    @Test
    void sothichTrongThiIsEmptyDungDeVideoServiceQuayVeFeedThuong() {
        assertThat(new ForYouRanker.Preferences(null, Set.of()).isEmpty()).isTrue();
        assertThat(new ForYouRanker.Preferences(null, null).isEmpty()).isTrue();
        assertThat(new ForYouRanker.Preferences(JLPTLevel.N5, Set.of()).isEmpty()).isFalse();
        assertThat(new ForYouRanker.Preferences(null, Set.of(1L)).isEmpty()).isFalse();
    }
}
