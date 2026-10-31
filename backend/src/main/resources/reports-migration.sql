-- Báo cáo vi phạm (video / bình luận / tài khoản).
-- Profile dev dùng ddl-auto=update nên tự tạo; prod (validate) cần chạy script này một lần.
-- Đối tượng bị báo cáo tham chiếu bằng (target_type, target_id), không có khóa ngoại,
-- để báo cáo vẫn còn khi nội dung đã bị xóa.

CREATE TABLE IF NOT EXISTS reports (
    id              BIGSERIAL PRIMARY KEY,
    reporter_id     BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    target_type     VARCHAR(20)  NOT NULL,
    target_id       BIGINT       NOT NULL,
    reason          VARCHAR(30)  NOT NULL,
    detail          VARCHAR(500),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    action          VARCHAR(20),
    resolved_by     BIGINT,
    resolved_at     TIMESTAMP,
    resolution_note VARCHAR(500),
    created_at      TIMESTAMP    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reports_status_created ON reports (status, created_at);
CREATE INDEX IF NOT EXISTS idx_reports_target ON reports (target_type, target_id);
