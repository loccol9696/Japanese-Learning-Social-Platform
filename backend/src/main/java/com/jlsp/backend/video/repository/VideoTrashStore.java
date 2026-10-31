package com.jlsp.backend.video.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Các thao tác thùng rác tác động lên video và mọi bảng phụ thuộc cùng lúc. Dùng SQL thuần vì
 * @SQLRestriction ẩn dòng đã xóa mềm khỏi JPA, nên JPA không khôi phục hay xóa hẳn được chúng.
 */
@Repository
@RequiredArgsConstructor
public class VideoTrashStore {

    /** Mọi bảng tham chiếu videos qua cột video_id. Bảng mới phụ thuộc video phải thêm vào đây. */
    private static final List<String> DEPENDENT_TABLES = List.of(
            "video_comments",
            "video_likes",
            "video_saves",
            "shadowing_practice",
            "shadowing_line_attempts");

    private final JdbcTemplate jdbc;

    /** Xóa mềm video và dữ liệu phụ thuộc với cùng một mốc thời gian. */
    public void softDelete(Long videoId, LocalDateTime deletedAt) {
        for (String table : DEPENDENT_TABLES) {
            jdbc.update("UPDATE " + table + " SET deleted_at = ? WHERE video_id = ? AND deleted_at IS NULL",
                    deletedAt, videoId);
        }
        jdbc.update("UPDATE videos SET deleted_at = ? WHERE id = ?", deletedAt, videoId);
    }

    public void restore(Long videoId) {
        for (String table : DEPENDENT_TABLES) {
            jdbc.update("UPDATE " + table + " SET deleted_at = NULL WHERE video_id = ?", videoId);
        }
        jdbc.update("UPDATE videos SET deleted_at = NULL WHERE id = ?", videoId);
    }

    /** Xóa hẳn, gồm cả dòng phụ thuộc để không vướng khóa ngoại tới videos. */
    public void hardDelete(Long videoId) {
        for (String table : DEPENDENT_TABLES) {
            jdbc.update("DELETE FROM " + table + " WHERE video_id = ?", videoId);
        }
        jdbc.update("DELETE FROM videos WHERE id = ?", videoId);
    }

    /** Một file có thể dùng chung cho nhiều video (dữ liệu mẫu, đăng lại); còn video dùng thì giữ file. */
    public boolean isMediaInUse(String url) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM videos WHERE video_url = ? OR thumbnail_url = ?", Integer.class, url, url);
        return count != null && count > 0;
    }
}
