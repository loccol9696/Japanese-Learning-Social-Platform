-- Thông báo trong ứng dụng (thích, bình luận, theo dõi, kiểm duyệt video, kết quả báo cáo).
-- Profile dev dùng ddl-auto=update nên tự tạo; prod (validate) cần chạy script này một lần.
-- video_id / comment_id chỉ là tham chiếu (không khóa ngoại) để thông báo còn khi nội dung bị xóa.

CREATE TABLE IF NOT EXISTS notifications (
    id           BIGSERIAL PRIMARY KEY,
    recipient_id BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    actor_id     BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    type         VARCHAR(30) NOT NULL,
    video_id     BIGINT,
    comment_id   BIGINT,
    message      VARCHAR(500),
    is_read      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP   NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created ON notifications (recipient_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_read ON notifications (recipient_id, is_read);
