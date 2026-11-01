package com.jlsp.backend.video.service;

import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class ForYouRankerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 29, 12, 0);

    private static Video video(long id, JLPTLevel level, Long topicId, long views) {
        return Video.builder()
                .id(id)
                .jlptLevel(level)
                .topics(topicId == null ? new HashSet<>() : new HashSet<>(Set.of(Topic.builder().id(topicId).build())))
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
    void videoKhopKhiMotTrongCacChuDeNamTrongSoThich() {
        Video nhieuChuDe = video(1L, JLPTLevel.N1, 3L, 0);
        nhieuChuDe.getTopics().add(Topic.builder().id(7L).build());
        Video khongKhop = video(2L, JLPTLevel.N1, 3L, 0);

        var ranked = ForYouRanker.rank(List.of(khongKhop, nhieuChuDe),
                new ForYouRanker.Preferences(null, Set.of(7L)), NOW);

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

    private static Video engaged(long id, long views, int likes, int saves) {
        Video v = video(id, JLPTLevel.N5, 7L, views);
        v.setLikeCount(likes);
        v.setSaveCount(saves);
        return v;
    }

    private static final ForYouRanker.Preferences N5_TOPIC7 = new ForYouRanker.Preferences(JLPTLevel.N5, Set.of(7L));

    @Test
    void videoMotXemMotThichKhongThangVideoNhieuLuotXemVaTuongTac() {
        Video it = engaged(1, 1, 1, 0);
        Video nhieu = engaged(2, 500, 40, 10);

        assertThat(ids(ForYouRanker.rank(List.of(it, nhieu), N5_TOPIC7, NOW))).containsExactly(2L, 1L);
    }

    @Test
    void binhLuanVaLuyenShadowingDayVideoLenTrenVideoChiNhieuLuotXem() {
        Video chiXem = engaged(1, 1_000, 0, 0);
        Video hocNhieu = engaged(2, 400, 0, 0);
        Map<Long, ForYouRanker.Extras> extras = Map.of(2L, new ForYouRanker.Extras(30, 25, 0));

        assertThat(ids(ForYouRanker.rank(List.of(chiXem, hocNhieu), N5_TOPIC7, extras, NOW)))
                .containsExactly(2L, 1L);
        // Không có tín hiệu bổ sung thì video nhiều lượt xem hơn đứng trước như cũ.
        assertThat(ids(ForYouRanker.rank(List.of(chiXem, hocNhieu), N5_TOPIC7, NOW))).containsExactly(1L, 2L);
    }

    @Test
    void videoBiBaoCaoDangChoXuLyBiDayXuongDuoiVideoSach() {
        Video biBaoCao = engaged(1, 1_000, 100, 20);
        Video sach = engaged(2, 100, 5, 0);
        Map<Long, ForYouRanker.Extras> extras = Map.of(1L, new ForYouRanker.Extras(0, 0, 2));

        assertThat(ids(ForYouRanker.rank(List.of(biBaoCao, sach), N5_TOPIC7, NOW))).containsExactly(1L, 2L);
        assertThat(ids(ForYouRanker.rank(List.of(biBaoCao, sach), N5_TOPIC7, extras, NOW))).containsExactly(2L, 1L);
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
