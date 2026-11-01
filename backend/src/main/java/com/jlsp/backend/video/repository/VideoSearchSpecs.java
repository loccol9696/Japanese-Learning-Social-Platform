package com.jlsp.backend.video.repository;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/**
 * Dựng truy vấn tìm kiếm video công khai đã duyệt. So khớp từ khoá không phân biệt hoa thường và dấu,
 * cần extension {@code unaccent} (xem video-classification-migration.sql).
 */
public final class VideoSearchSpecs {

    private static final char LIKE_ESCAPE = '\\';

    private VideoSearchSpecs() {
    }

    /**
     * Điều kiện tìm kiếm; các trường null / rỗng được bỏ qua.
     *
     * @param keyword           Khớp một phần tiêu đề, mô tả, tên chủ đề, hashtag hoặc người đăng
     * @param hashtag           Tên hashtag đã chuẩn hoá, khớp nguyên thẻ
     * @param topicIds          Video thuộc ít nhất một chủ đề trong danh sách
     * @param jlptLevel         Trình độ
     * @param excludedAuthorIds Tác giả bị loại (quan hệ chặn), không được rỗng
     * @param byRelevance       Xếp khớp tiêu đề lên trước; khi đó Pageable không được kèm sort
     */
    public record Filter(String keyword, String hashtag, Collection<Long> topicIds, JLPTLevel jlptLevel,
                         Collection<Long> excludedAuthorIds, boolean byRelevance) {
    }

    public static Specification<Video> matching(Filter filter) {
        return (root, query, cb) -> {
            List<Predicate> conditions = new ArrayList<>();
            conditions.add(cb.equal(root.get("status"), VideoStatus.PUBLIC));
            conditions.add(cb.equal(root.get("modStatus"), VideoModStatus.APPROVED));
            conditions.add(cb.not(root.get("user").get("id").in(filter.excludedAuthorIds())));

            if (filter.jlptLevel() != null) {
                conditions.add(cb.equal(root.get("jlptLevel"), filter.jlptLevel()));
            }
            if (filter.topicIds() != null && !filter.topicIds().isEmpty()) {
                conditions.add(hasTopicIn(filter.topicIds(), root, query, cb));
            }
            if (filter.hashtag() != null) {
                conditions.add(hasExactHashtag(filter.hashtag(), root, query, cb));
            }
            if (filter.keyword() != null) {
                conditions.add(matchesKeyword(filter.keyword(), root, query, cb));
                // Câu đếm tổng số dòng cũng đi qua đây nhưng không được có ORDER BY.
                if (filter.byRelevance() && query.getResultType() != Long.class) {
                    orderByRelevance(filter.keyword(), root, query, cb);
                }
            }
            return cb.and(conditions.toArray(Predicate[]::new));
        };
    }

    /** Thoát ký tự đặc biệt của LIKE để "100%" hay "n_5" được so khớp đúng từng ký tự. */
    public static String escapeLike(String text) {
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private static Predicate matchesKeyword(String keyword, Root<Video> root, CriteriaQuery<?> query,
                                            CriteriaBuilder cb) {
        Expression<String> contains = pattern(cb, "%" + escapeLike(keyword) + "%");
        Path<Object> user = root.get("user");

        Subquery<Long> topicName = query.subquery(Long.class);
        Root<Video> topicVideo = topicName.from(Video.class);
        Join<Video, ?> topic = topicVideo.join("topics");
        topicName.select(topicVideo.get("id")).where(
                cb.equal(topicVideo.get("id"), root.get("id")),
                like(cb, topic.get("name"), contains));

        Subquery<Long> hashtagName = query.subquery(Long.class);
        Root<Video> hashtagVideo = hashtagName.from(Video.class);
        Join<Video, ?> hashtag = hashtagVideo.join("hashtags");
        hashtagName.select(hashtagVideo.get("id")).where(
                cb.equal(hashtagVideo.get("id"), root.get("id")),
                like(cb, hashtag.get("name"), contains));

        return cb.or(
                like(cb, root.get("title"), contains),
                like(cb, root.get("description"), contains),
                like(cb, user.get("displayName"), contains),
                like(cb, user.get("username"), contains),
                cb.exists(topicName),
                cb.exists(hashtagName));
    }

    /** EXISTS thay vì JOIN để video gắn nhiều chủ đề khớp không bị lặp dòng hay đếm sai tổng số trang. */
    private static Predicate hasTopicIn(Collection<Long> topicIds, Root<Video> root, CriteriaQuery<?> query,
                                        CriteriaBuilder cb) {
        Subquery<Long> sub = query.subquery(Long.class);
        Root<Video> video = sub.from(Video.class);
        Join<Video, ?> topic = video.join("topics");
        sub.select(video.get("id")).where(
                cb.equal(video.get("id"), root.get("id")),
                topic.get("id").in(topicIds));
        return cb.exists(sub);
    }

    private static Predicate hasExactHashtag(String name, Root<Video> root, CriteriaQuery<?> query,
                                             CriteriaBuilder cb) {
        Subquery<Long> sub = query.subquery(Long.class);
        Root<Video> video = sub.from(Video.class);
        Join<Video, ?> hashtag = video.join("hashtags");
        sub.select(video.get("id")).where(
                cb.equal(video.get("id"), root.get("id")),
                cb.equal(folded(cb, hashtag.get("name")), pattern(cb, name)));
        return cb.exists(sub);
    }

    private static void orderByRelevance(String keyword, Root<Video> root, CriteriaQuery<?> query,
                                         CriteriaBuilder cb) {
        String escaped = escapeLike(keyword);
        Expression<String> title = folded(cb, root.get("title"));
        Expression<Integer> rank = cb.<Integer>selectCase()
                .when(cb.equal(title, pattern(cb, keyword)), 0)
                .when(cb.like(title, pattern(cb, escaped + "%"), LIKE_ESCAPE), 1)
                .when(cb.like(title, pattern(cb, "%" + escaped + "%"), LIKE_ESCAPE), 2)
                .otherwise(3);
        query.orderBy(cb.asc(rank), cb.desc(root.get("createdAt")), cb.desc(root.get("id")));
    }

    private static Predicate like(CriteriaBuilder cb, Path<String> column, Expression<String> foldedPattern) {
        return cb.like(folded(cb, column), foldedPattern, LIKE_ESCAPE);
    }

    private static Expression<String> pattern(CriteriaBuilder cb, String value) {
        return folded(cb, cb.literal(value));
    }

    /**
     * unaccent chạy trước lower: "Đ" được đổi thành "D" rồi mới hạ chữ thường, nên kết quả không phụ thuộc
     * vào locale của CSDL.
     */
    private static Expression<String> folded(CriteriaBuilder cb, Expression<String> value) {
        return cb.lower(cb.function("unaccent", String.class, value));
    }
}
