-- Mỗi video có nhiều chủ đề (video_topics) và hashtag (hashtags, video_hashtags); tìm kiếm không phân biệt dấu.
-- ddl-auto=update tự tạo các bảng nhưng KHÔNG cài extension và KHÔNG chép dữ liệu cũ, nên mọi môi trường
-- (cả dev) đều phải chạy script này MỘT lần. Chạy lại sẽ khôi phục chủ đề cũ đã bị người đăng gỡ.

-- Ô tìm kiếm và gợi ý hashtag gọi unaccent(); thiếu extension thì các truy vấn đó báo lỗi.
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE IF NOT EXISTS video_topics (
    video_id BIGINT NOT NULL REFERENCES videos (id) ON DELETE CASCADE,
    topic_id BIGINT NOT NULL REFERENCES topics (id),
    PRIMARY KEY (video_id, topic_id)
);
CREATE INDEX IF NOT EXISTS idx_video_topics_topic ON video_topics (topic_id, video_id);

CREATE TABLE IF NOT EXISTS hashtags (
    id   BIGSERIAL PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS video_hashtags (
    video_id   BIGINT NOT NULL REFERENCES videos (id) ON DELETE CASCADE,
    hashtag_id BIGINT NOT NULL REFERENCES hashtags (id),
    PRIMARY KEY (video_id, hashtag_id)
);
CREATE INDEX IF NOT EXISTS idx_video_hashtags_hashtag ON video_hashtags (hashtag_id, video_id);

-- Chép chủ đề đơn cũ sang bảng nối.
INSERT INTO video_topics (video_id, topic_id)
SELECT id, topic_id FROM videos WHERE topic_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Cột cũ vẫn được code của các nhánh chưa cập nhật dùng. Chỉ chạy phần dưới sau khi mọi nơi đã lên bản mới:
-- DROP INDEX IF EXISTS idx_videos_topic_feed;
-- DROP INDEX IF EXISTS idx_videos_topic;
-- ALTER TABLE videos DROP COLUMN IF EXISTS topic_id;
