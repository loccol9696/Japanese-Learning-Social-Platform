package com.jlsp.backend.video.service;

import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.video.entity.VideoComment;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class CommentRankerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 1, 12, 0);
    private static final String LONG_TEXT = "Cảm ơn bạn, mình đã hiểu cách dùng ngữ pháp này rồi";

    private static VideoComment comment(long id, long userId, int likes, LocalDateTime createdAt, String content) {
        return VideoComment.builder()
                .id(id)
                .user(User.builder().id(userId).build())
                .content(content)
                .likeCount(likes)
                .createdAt(createdAt)
                .build();
    }

    private static VideoComment old(long id, long userId, int likes) {
        return comment(id, userId, likes, NOW.minusDays(10), LONG_TEXT);
    }

    private static List<Long> ids(List<VideoComment> comments) {
        return comments.stream().map(VideoComment::getId).toList();
    }

    @Test
    void nhieuLuotThichVaPhanHoiVuotBinhLuanMotLuotThich() {
        VideoComment mot = old(1, 10, 1);
        VideoComment nhieu = old(2, 11, 5);
        Map<Long, List<VideoComment>> replies = Map.of(2L, List.of(old(3, 20, 0), old(4, 21, 0), old(5, 22, 0)));

        assertThat(ids(CommentRanker.rank(List.of(mot, nhieu), replies, NOW))).containsExactly(2L, 1L);
    }

    @Test
    void phanHoiThaoLuanCoTrongSoNangHonLuotThich() {
        VideoComment nhieuThich = old(1, 10, 3);
        VideoComment nhieuPhanHoi = old(2, 11, 0);
        Map<Long, List<VideoComment>> replies = Map.of(2L, List.of(old(3, 20, 0), old(4, 21, 0), old(5, 22, 0)));

        assertThat(ids(CommentRanker.rank(List.of(nhieuThich, nhieuPhanHoi), replies, NOW))).containsExactly(2L, 1L);
    }

    @Test
    void tacGiaTuTraLoiHayMotNguoiTraLoiNhieuLanKhongTangDiem() {
        VideoComment tuTraLoi = old(1, 10, 0);
        VideoComment motNguoi = old(2, 11, 0);
        VideoComment khongPhanHoi = old(3, 12, 0);
        Map<Long, List<VideoComment>> replies = Map.of(
                1L, List.of(old(4, 10, 0), old(5, 10, 0)),
                2L, List.of(old(6, 20, 0), old(7, 20, 0), old(8, 20, 0)));

        assertThat(CommentRanker.score(tuTraLoi, replies.get(1L), 0, NOW))
                .isEqualTo(CommentRanker.score(khongPhanHoi, List.of(), 0, NOW));
        assertThat(CommentRanker.score(motNguoi, replies.get(2L), 0, NOW))
                .isGreaterThan(CommentRanker.score(khongPhanHoi, List.of(), 0, NOW))
                .isEqualTo(CommentRanker.score(motNguoi, List.of(old(9, 20, 0)), 0, NOW));
    }

    @Test
    void binhLuanQuaNganKhongDuocDiemDoDai() {
        assertThat(CommentRanker.lengthQuality("ok")).isZero();
        assertThat(CommentRanker.lengthQuality("   ")).isZero();
        assertThat(CommentRanker.lengthQuality(null)).isZero();
        assertThat(CommentRanker.lengthQuality(LONG_TEXT)).isEqualTo(1.0);
        assertThat(CommentRanker.lengthQuality("すごいですね")).isBetween(0.0, 1.0);
    }

    @Test
    void binhLuanMoiDuocCongDiemVaTatDanTheoGio() {
        assertThat(CommentRanker.newBoost(NOW, NOW)).isEqualTo(1.0);
        assertThat(CommentRanker.newBoost(NOW.minusHours(12), NOW)).isEqualTo(0.5);
        assertThat(CommentRanker.newBoost(NOW.minusHours(30), NOW)).isZero();
        assertThat(CommentRanker.newBoost(null, NOW)).isZero();
    }

    @Test
    void binhLuanMoiChuaCoThichCoTheVuotBinhLuanCuMotThich() {
        VideoComment cuMotThich = comment(1, 10, 1, NOW.minusDays(40), LONG_TEXT);
        VideoComment moiChuaThich = comment(2, 11, 0, NOW.minusMinutes(5), LONG_TEXT);

        assertThat(ids(CommentRanker.rank(List.of(cuMotThich, moiChuaThich), Map.of(), NOW))).containsExactly(2L, 1L);
    }

    @Test
    void diemGiamNhieuTheoTuoiNhungBinhLuanHayVanDuocGiu() {
        assertThat(CommentRanker.decay(NOW, NOW)).isEqualTo(1.0);
        assertThat(CommentRanker.decay(NOW.minusDays(60), NOW)).isCloseTo(0.5, org.assertj.core.data.Offset.offset(1e-9));
        assertThat(CommentRanker.decay(null, NOW)).isEqualTo(1.0);
    }

    @Test
    void cungDiemThiBinhLuanMoiHonDungTruocVaThuTuOnDinh() {
        VideoComment a = comment(1, 10, 0, NOW.minusDays(20), LONG_TEXT);
        VideoComment b = comment(2, 11, 0, NOW.minusDays(20), LONG_TEXT);
        VideoComment c = comment(3, 12, 0, NOW.minusDays(21), LONG_TEXT);
        // c cũ hơn một ngày nên điểm thấp hơn; a và b bằng điểm thì id lớn hơn đứng trước.
        List<Long> first = ids(CommentRanker.rank(List.of(a, b, c), Map.of(), NOW));
        List<Long> again = ids(CommentRanker.rank(List.of(c, b, a), Map.of(), NOW));

        assertThat(first).containsExactly(2L, 1L, 3L);
        assertThat(again).isEqualTo(first);
    }

    @Test
    void moiBaoCaoDangChoXuLyNhanDoiDiemXuong() {
        VideoComment bi = old(1, 10, 8);
        VideoComment sach = old(2, 11, 3);

        // Không bị báo cáo thì 8 lượt thích thắng; có báo cáo thì tụt xuống dưới bình luận 3 lượt thích.
        assertThat(ids(CommentRanker.rank(List.of(bi, sach), Map.of(), NOW))).containsExactly(1L, 2L);
        assertThat(ids(CommentRanker.rank(List.of(bi, sach), Map.of(), Map.of(1L, 2L), NOW))).containsExactly(2L, 1L);
        assertThat(CommentRanker.score(bi, List.of(), 1, NOW))
                .isCloseTo(CommentRanker.score(bi, List.of(), 0, NOW) / 2, org.assertj.core.data.Offset.offset(1e-9));
    }

    @Test
    void danhSachRongTraRong() {
        assertThat(CommentRanker.rank(List.of(), Map.of(), NOW)).isEmpty();
    }
}
