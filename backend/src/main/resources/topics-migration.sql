-- Chủ đề (topics): dùng cho video và sở thích hồ sơ người dùng.
-- Profile dev dùng ddl-auto=update nên tự tạo; prod (validate) cần chạy script này một lần.
-- 9 chủ đề mặc định được ứng dụng seed lúc khởi động khi bảng topics còn trống.

CREATE TABLE IF NOT EXISTS topics (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(80) NOT NULL UNIQUE,
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
    sort_order INTEGER     NOT NULL DEFAULT 0
);

ALTER TABLE videos ADD COLUMN IF NOT EXISTS topic_id BIGINT REFERENCES topics (id);
CREATE INDEX IF NOT EXISTS idx_videos_topic ON videos (topic_id);

CREATE TABLE IF NOT EXISTS user_topics (
    user_id  BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    topic_id BIGINT NOT NULL REFERENCES topics (id),
    PRIMARY KEY (user_id, topic_id)
);
