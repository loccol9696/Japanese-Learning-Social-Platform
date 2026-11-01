package com.jlsp.backend.video.service;

import com.jlsp.backend.video.entity.VideoComment;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Xếp bình luận gốc của video theo mức "hữu ích".
 *
 * <p>Điểm = (1·ln(1+lượt thích) + 1,5·ln(1+số người khác đã trả lời) + 0,5·độ dài hợp lý + 0,8·độ mới)
 * × hệ số giảm theo tuổi × 0,5^số báo cáo đang chờ xử lý. Phản hồi được tính nặng hơn lượt thích vì một cuộc thảo luận cho thấy bình luận
 * khơi được trao đổi (cách Facebook ưu tiên bình luận có qua lại). Thứ tự hoàn toàn xác định: cùng điểm thì
 * bình luận mới hơn đứng trước.
 */
public final class CommentRanker {

    public static final double W_LIKES = 1.0;
    public static final double W_REPLIES = 1.5;
    public static final double W_LENGTH = 0.5;
    public static final double W_NEW = 0.8;

    /** Mỗi báo cáo đang chờ xử lý nhân điểm với hệ số này; báo cáo bị bác bỏ hay đã xử lý thì hết bị trừ. */
    public static final double REPORT_PENALTY = 0.5;

    /** Dưới ngần này ký tự (đã trim) thì không được điểm độ dài; từ {@value #FULL_LENGTH} trở lên được trọn điểm. */
    static final int MIN_LENGTH = 5;
    static final int FULL_LENGTH = 20;

    /** Bình luận mới được cộng điểm, tắt dần về 0 sau chừng này giờ để có cơ hội nhận lượt thích đầu tiên. */
    static final double NEW_BOOST_HOURS = 24.0;

    /** Sau chừng này ngày điểm giảm còn một nửa; đủ dài để bình luận hay không bị chôn. */
    static final double DECAY_HALF_LIFE_DAYS = 60.0;

    private CommentRanker() {
    }

    /**
     * Xếp lại {@code roots}; trả danh sách mới, không sửa danh sách vào.
     *
     * @param repliesByParent phản hồi gom theo id bình luận gốc (bình luận không có phản hồi có thể vắng mặt)
     */
    public static List<VideoComment> rank(List<VideoComment> roots, Map<Long, List<VideoComment>> repliesByParent,
            LocalDateTime now) {
        return rank(roots, repliesByParent, Map.of(), now);
    }

    /**
     * @param pendingReports số báo cáo đang chờ xử lý theo id bình luận; bình luận vắng mặt coi như không bị báo cáo
     */
    public static List<VideoComment> rank(List<VideoComment> roots, Map<Long, List<VideoComment>> repliesByParent,
            Map<Long, Long> pendingReports, LocalDateTime now) {
        Comparator<VideoComment> byScore = Comparator
                .comparingDouble((VideoComment c) -> score(c, repliesByParent.getOrDefault(c.getId(), List.of()),
                        pendingReports.getOrDefault(c.getId(), 0L), now))
                .reversed()
                .thenComparing(VideoComment::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(VideoComment::getId, Comparator.nullsLast(Comparator.reverseOrder()));
        return roots.stream().sorted(byScore).toList();
    }

    static double score(VideoComment comment, List<VideoComment> replies, long pendingReports, LocalDateTime now) {
        int likes = comment.getLikeCount() == null ? 0 : comment.getLikeCount();
        double base = W_LIKES * Math.log1p(likes)
                + W_REPLIES * Math.log1p(otherRepliers(comment, replies))
                + W_LENGTH * lengthQuality(comment.getContent())
                + W_NEW * newBoost(comment.getCreatedAt(), now);
        return base * decay(comment.getCreatedAt(), now) * Math.pow(REPORT_PENALTY, pendingReports);
    }

    /** Số người khác nhau (không kể chính tác giả) đã trả lời; tự trả lời hay một người trả lời nhiều lần không tăng điểm. */
    private static long otherRepliers(VideoComment comment, List<VideoComment> replies) {
        Long authorId = comment.getUser() == null ? null : comment.getUser().getId();
        return replies.stream()
                .map(r -> r.getUser() == null ? null : r.getUser().getId())
                .filter(Objects::nonNull)
                .filter(id -> !id.equals(authorId))
                .distinct()
                .count();
    }

    /** 0 nếu quá ngắn, tăng tuyến tính đến 1 rồi giữ nguyên. */
    static double lengthQuality(String content) {
        int length = content == null ? 0 : content.strip().codePointCount(0, content.strip().length());
        if (length < MIN_LENGTH) {
            return 0;
        }
        return Math.min(1.0, (double) (length - MIN_LENGTH) / (FULL_LENGTH - MIN_LENGTH));
    }

    static double newBoost(LocalDateTime createdAt, LocalDateTime now) {
        if (createdAt == null) {
            return 0;
        }
        double hours = Math.max(0, Duration.between(createdAt, now).toMinutes() / 60.0);
        return Math.max(0, 1.0 - hours / NEW_BOOST_HOURS);
    }

    static double decay(LocalDateTime createdAt, LocalDateTime now) {
        if (createdAt == null) {
            return 1;
        }
        double days = Math.max(0, Duration.between(createdAt, now).toHours() / 24.0);
        return Math.pow(0.5, days / DECAY_HALF_LIFE_DAYS);
    }
}
