-- Báo cáo tin nhắn, bản dịch và mẫu ngữ pháp. Chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Môi trường dev (ddl-auto=update) tự thêm cột; các CHECK do ReportSchemaUpdater gỡ lúc khởi động.
ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_key VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_snapshot TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS snapshot_image_url VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS violation_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS removed_by_moderation BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS report_id BIGINT;

ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reason_check;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_action_check;
