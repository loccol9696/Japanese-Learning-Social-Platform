-- Đếm lượt chia sẻ video cho bạn bè qua chat, và các loại thông báo mới VIDEO_SAVED / VIDEO_SHARED.
-- Chạy tay trên môi trường dùng ddl-auto=validate (prod). Môi trường dev (ddl-auto=update) tự thêm cột.
-- Lượt chia sẻ cũ không được tính lại: bắt đầu từ 0, hoặc đếm lại từ các tin VIDEO_SHARE đã gửi bằng lệnh dưới.
ALTER TABLE videos ADD COLUMN IF NOT EXISTS share_count integer NOT NULL DEFAULT 0;

-- (Tuỳ chọn) Tính lại từ lịch sử tin nhắn:
-- UPDATE videos v SET share_count = (SELECT COUNT(*) FROM messages m WHERE m.video_id = v.id AND m.type = 'VIDEO_SHARE');
