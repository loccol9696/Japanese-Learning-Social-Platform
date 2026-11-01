-- Đánh giá hữu ích cho bình luận. Chạy tay trên môi trường dùng ddl-auto=validate (prod). Môi
-- trường dev (ddl-auto=update) tự tạo bảng và cột.
ALTER TABLE video_comments ADD COLUMN IF NOT EXISTS like_count integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS comment_likes (
    user_id bigint NOT NULL REFERENCES users (id),
    comment_id bigint NOT NULL REFERENCES video_comments (id) ON DELETE CASCADE,
    created_at timestamp(6) NOT NULL,
    PRIMARY KEY (user_id, comment_id)
);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON comment_likes (comment_id);
