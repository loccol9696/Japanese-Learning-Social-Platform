-- Xóa mềm video: video và dữ liệu phụ thuộc mang cùng một deleted_at, hết hạn lưu mới xóa hẳn.
-- Chạy tay trên môi trường dùng ddl-auto=validate (prod). Môi trường dev (ddl-auto=update) tự
-- tạo cột.
ALTER TABLE videos ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);
ALTER TABLE video_comments ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);
ALTER TABLE video_likes ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);
ALTER TABLE video_saves ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);
ALTER TABLE shadowing_practice ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);
ALTER TABLE shadowing_line_attempts ADD COLUMN IF NOT EXISTS deleted_at timestamp(6);

CREATE INDEX IF NOT EXISTS idx_videos_deleted_at ON videos (deleted_at);
