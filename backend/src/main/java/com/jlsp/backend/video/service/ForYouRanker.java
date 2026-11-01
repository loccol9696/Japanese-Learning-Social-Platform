package com.jlsp.backend.video.service;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Xếp hạng video cho feed "Dành cho bạn" theo trình độ và sở thích người dùng đã trả lời.
 *
 * <p>Điểm = 3·khớp trình độ + 2·khớp chủ đề + 1·độ phổ biến + 0,5·độ mới, trong đó độ phổ biến là trung bình
 * của lượng tương tác (log) và tỉ lệ tương tác trên lượt xem. Thứ tự hoàn toàn xác định
 * (không ngẫu nhiên) để các trang liên tiếp của cùng một danh sách không bị lặp hay sót video.
 * Cứ mỗi {@value #EXPLORE_EVERY} video lại chèn một video ngoài sở thích để người xem không bị nhốt trong một vùng.
 */
public final class ForYouRanker {

    public static final double W_LEVEL = 3.0;
    public static final double W_TOPIC = 2.0;
    public static final double W_POPULARITY = 1.0;
    public static final double W_FRESHNESS = 0.5;

    /** Vị trí thứ N trong danh sách (đếm từ 1) dành cho video khám phá. */
    public static final int EXPLORE_EVERY = 5;

    /** Mỗi báo cáo đang chờ xử lý nhân điểm video với hệ số này; xử lý xong hay bác bỏ thì hết bị trừ. */
    public static final double REPORT_PENALTY = 0.5;

    /** Sau chừng này ngày điểm "mới" giảm còn một nửa. */
    private static final double FRESHNESS_HALF_LIFE_DAYS = 14.0;

    /** Số lượt xem "ảo" khi làm mượt tỉ lệ tương tác: càng lớn thì video ít lượt xem càng bị kéo về mức trung bình. */
    private static final double RATE_PRIOR_VIEWS = 50.0;

    private ForYouRanker() {
    }

    /** Sở thích của người xem; cả hai trường đều có thể trống. */
    public record Preferences(JLPTLevel level, Set<Long> topicIds) {
        public boolean isEmpty() {
            return level == null && (topicIds == null || topicIds.isEmpty());
        }
    }

    /**
     * Tín hiệu nằm ngoài bảng videos: số bình luận, số người đã luyện shadowing, và số báo cáo đang chờ xử lý
     * (tín hiệu âm: mỗi báo cáo nhân điểm với {@value #REPORT_PENALTY}).
     */
    public record Extras(long comments, long shadowing, long reports) {
        static final Extras NONE = new Extras(0, 0, 0);
    }

    /** Như {@link #rank(List, Preferences, Map, LocalDateTime)} khi không có tín hiệu bổ sung. */
    public static List<Video> rank(List<Video> candidates, Preferences prefs, LocalDateTime now) {
        return rank(candidates, prefs, Map.of(), now);
    }

    /**
     * Xếp lại {@code candidates}; trả danh sách mới, không sửa danh sách vào.
     *
     * @param extras tín hiệu bổ sung theo id video; video vắng mặt coi như chưa có
     */
    public static List<Video> rank(List<Video> candidates, Preferences prefs, Map<Long, Extras> extras,
            LocalDateTime now) {
        if (candidates.isEmpty()) {
            return List.of();
        }
        double priorRate = priorRate(candidates, extras);
        double maxVolume = candidates.stream().mapToDouble(v -> volume(v, extra(extras, v))).max().orElse(0);
        double maxRate = candidates.stream().mapToDouble(v -> smoothedRate(v, extra(extras, v), priorRate)).max()
                .orElse(0);

        record Scored(Video video, double score, boolean matches) {
        }
        List<Scored> scored = new ArrayList<>(candidates.size());
        for (Video v : candidates) {
            double level = levelFit(prefs.level(), v.getJlptLevel());
            boolean topicHit = topicHit(prefs.topicIds(), v);
            Extras ex = extra(extras, v);
            double volumeScore = maxVolume <= 0 ? 0 : volume(v, ex) / maxVolume;
            double rateScore = maxRate <= 0 ? 0 : smoothedRate(v, ex, priorRate) / maxRate;
            double popularity = (volumeScore + rateScore) / 2;
            double score = (W_LEVEL * level
                    + W_TOPIC * (topicHit ? 1 : 0)
                    + W_POPULARITY * popularity
                    + W_FRESHNESS * freshness(v.getCreatedAt(), now))
                    * Math.pow(REPORT_PENALTY, ex.reports());
            scored.add(new Scored(v, score, topicHit || level >= 0.5));
        }

        Comparator<Scored> byScore = Comparator.comparingDouble(Scored::score).reversed()
                .thenComparing((Scored s) -> s.video().getCreatedAt(),
                        Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing((Scored s) -> s.video().getId(), Comparator.reverseOrder());
        scored.sort(byScore);

        List<Video> matched = new ArrayList<>();
        List<Video> explore = new ArrayList<>();
        for (Scored s : scored) {
            (s.matches() ? matched : explore).add(s.video());
        }

        List<Video> result = new ArrayList<>(candidates.size());
        int m = 0;
        int e = 0;
        while (m < matched.size() || e < explore.size()) {
            boolean exploreSlot = (result.size() + 1) % EXPLORE_EVERY == 0;
            if ((exploreSlot && e < explore.size()) || m >= matched.size()) {
                result.add(explore.get(e++));
            } else {
                result.add(matched.get(m++));
            }
        }
        return result;
    }

    /** 1 nếu đúng trình độ, 0,5 nếu lệch một bậc, 0 nếu xa hơn; video chưa gắn trình độ được 0,3. */
    static double levelFit(JLPTLevel wanted, JLPTLevel actual) {
        if (wanted == null) {
            return 0;
        }
        if (actual == null) {
            return 0.3;
        }
        int diff = Math.abs(wanted.ordinal() - actual.ordinal());
        return diff == 0 ? 1.0 : diff == 1 ? 0.5 : 0;
    }

    private static boolean topicHit(Set<Long> topicIds, Video v) {
        return topicIds != null && v.getTopics().stream().anyMatch(t -> topicIds.contains(t.getId()));
    }

    /**
     * Mức độ tương tác nhiều/ít: lượt xem, thích, bình luận, lưu và luyện shadowing gộp lại, lấy log để một
     * video quá nổi không lấn át phần còn lại.
     */
    private static double volume(Video v, Extras ex) {
        return Math.log1p(views(v) + 3.0 * likes(v) + 3.0 * ex.comments() + 5.0 * saves(v) + 6.0 * ex.shadowing());
    }

    /**
     * Tỉ lệ tương tác trên mỗi lượt xem, kéo về mức trung bình của cả nhóm khi có ít lượt xem
     * (video 1 xem 1 thích không thắng video 500 xem 60 tương tác).
     */
    private static double smoothedRate(Video v, Extras ex, double priorRate) {
        return (interactions(v, ex) + RATE_PRIOR_VIEWS * priorRate) / (views(v) + RATE_PRIOR_VIEWS);
    }

    /** Tương tác có trọng số: bình luận, lưu và luyện shadowing đáng giá hơn một lượt thích. */
    private static double interactions(Video v, Extras ex) {
        return likes(v) + 3.0 * ex.comments() + 4.0 * saves(v) + 5.0 * ex.shadowing();
    }

    /** Tỉ lệ tương tác trung bình của cả nhóm ứng viên, dùng làm mốc kéo về khi video ít lượt xem. */
    private static double priorRate(List<Video> candidates, Map<Long, Extras> extras) {
        double interactions = 0;
        double views = 0;
        for (Video v : candidates) {
            interactions += interactions(v, extra(extras, v));
            views += views(v);
        }
        return views <= 0 ? 0 : interactions / views;
    }

    private static Extras extra(Map<Long, Extras> extras, Video v) {
        return extras.getOrDefault(v.getId(), Extras.NONE);
    }

    private static long views(Video v) {
        return v.getViewCount() == null ? 0 : v.getViewCount();
    }

    private static int likes(Video v) {
        return v.getLikeCount() == null ? 0 : v.getLikeCount();
    }

    private static int saves(Video v) {
        return v.getSaveCount() == null ? 0 : v.getSaveCount();
    }

    private static double freshness(LocalDateTime createdAt, LocalDateTime now) {
        if (createdAt == null) {
            return 0;
        }
        double days = Math.max(0, Duration.between(createdAt, now).toHours() / 24.0);
        return Math.pow(0.5, days / FRESHNESS_HALF_LIFE_DAYS);
    }
}
