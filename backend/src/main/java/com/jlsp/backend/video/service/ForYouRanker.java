package com.jlsp.backend.video.service;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

/**
 * Xếp hạng video cho feed "Dành cho bạn" theo trình độ và sở thích người dùng đã trả lời.
 *
 * <p>Điểm = 3·khớp trình độ + 2·khớp chủ đề + 1·độ phổ biến + 0,5·độ mới. Thứ tự hoàn toàn xác định
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

    /** Sau chừng này ngày điểm "mới" giảm còn một nửa. */
    private static final double FRESHNESS_HALF_LIFE_DAYS = 14.0;

    private ForYouRanker() {
    }

    /** Sở thích của người xem; cả hai trường đều có thể trống. */
    public record Preferences(JLPTLevel level, Set<Long> topicIds) {
        public boolean isEmpty() {
            return level == null && (topicIds == null || topicIds.isEmpty());
        }
    }

    /** Xếp lại {@code candidates}; trả danh sách mới, không sửa danh sách vào. */
    public static List<Video> rank(List<Video> candidates, Preferences prefs, LocalDateTime now) {
        if (candidates.isEmpty()) {
            return List.of();
        }
        double maxPopularity = candidates.stream().mapToDouble(ForYouRanker::rawPopularity).max().orElse(0);

        record Scored(Video video, double score, boolean matches) {
        }
        List<Scored> scored = new ArrayList<>(candidates.size());
        for (Video v : candidates) {
            double level = levelFit(prefs.level(), v.getJlptLevel());
            boolean topicHit = topicHit(prefs.topicIds(), v);
            double popularity = maxPopularity <= 0 ? 0 : rawPopularity(v) / maxPopularity;
            double score = W_LEVEL * level
                    + W_TOPIC * (topicHit ? 1 : 0)
                    + W_POPULARITY * popularity
                    + W_FRESHNESS * freshness(v.getCreatedAt(), now);
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
        return topicIds != null && v.getTopic() != null && topicIds.contains(v.getTopic().getId());
    }

    /** Lượt xem, thích, lưu gộp lại; lấy log để một video quá nổi không lấn át phần còn lại. */
    private static double rawPopularity(Video v) {
        long views = v.getViewCount() == null ? 0 : v.getViewCount();
        int likes = v.getLikeCount() == null ? 0 : v.getLikeCount();
        int saves = v.getSaveCount() == null ? 0 : v.getSaveCount();
        return Math.log1p(views + 3.0 * likes + 5.0 * saves);
    }

    private static double freshness(LocalDateTime createdAt, LocalDateTime now) {
        if (createdAt == null) {
            return 0;
        }
        double days = Math.max(0, Duration.between(createdAt, now).toHours() / 24.0);
        return Math.pow(0.5, days / FRESHNESS_HALF_LIFE_DAYS);
    }
}
