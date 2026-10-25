-- Luyện nói nhại theo từng dòng phụ đề: chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Môi trường dev (ddl-auto=update) tự tạo bảng này.
CREATE TABLE IF NOT EXISTS shadowing_line_attempts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users (id),
    video_id        BIGINT NOT NULL REFERENCES videos (id),
    line_index      INTEGER NOT NULL,
    expected_text   VARCHAR(1000) NOT NULL,
    recognized_text VARCHAR(1000),
    score           INTEGER NOT NULL,
    created_at      TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_shadowing_line_user_video ON shadowing_line_attempts (user_id, video_id);
