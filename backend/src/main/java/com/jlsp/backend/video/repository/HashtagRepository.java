package com.jlsp.backend.video.repository;

import com.jlsp.backend.video.entity.Hashtag;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface HashtagRepository extends JpaRepository<Hashtag, Long> {

    List<Hashtag> findByNameIn(Collection<String> names);

    /** Hai người đăng cùng một thẻ mới cùng lúc thì không ai bị lỗi trùng khoá. */
    @Modifying
    @Query(value = "INSERT INTO hashtags (name) VALUES (:name) ON CONFLICT (name) DO NOTHING", nativeQuery = true)
    void insertIfAbsent(@Param("name") String name);

    /**
     * Thẻ đang được dùng trên video công khai đã duyệt, phổ biến nhất trước. Không tính video riêng tư /
     * chưa duyệt để thẻ chưa qua kiểm duyệt không xuất hiện trong gợi ý.
     *
     * @param pattern mẫu LIKE đã thoát ký tự đặc biệt bằng "\"
     */
    @Query(value = """
            SELECT h.name AS "name", COUNT(*) AS "videoCount"
            FROM hashtags h
            JOIN video_hashtags vh ON vh.hashtag_id = h.id
            JOIN videos v ON v.id = vh.video_id
            WHERE v.status = 'PUBLIC' AND v.mod_status = 'APPROVED'
              AND lower(unaccent(h.name)) LIKE lower(unaccent(:pattern)) ESCAPE '\\'
            GROUP BY h.name
            ORDER BY COUNT(*) DESC, h.name
            LIMIT :limit
            """, nativeQuery = true)
    List<HashtagUsage> findPopular(@Param("pattern") String pattern, @Param("limit") int limit);

    interface HashtagUsage {
        String getName();

        long getVideoCount();
    }
}
