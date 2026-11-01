-- Chủ video ghim bình luận. Chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Môi trường dev (ddl-auto=update) tự thêm cột.
ALTER TABLE video_comments ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false;
