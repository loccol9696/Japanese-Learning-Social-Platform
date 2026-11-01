-- Chỉ mục cho feed video lọc theo chủ đề.
-- Profile dev dùng ddl-auto=update nên tự tạo từ @Index của entity Video; prod (validate) cần chạy script
-- này một lần. Nên kiểm tra bằng EXPLAIN ANALYZE trước / sau trên dữ liệu thật.
--
-- Cố ý không tạo chỉ mục trên view_count cho tab "Thịnh hành": cột này bị UPDATE ở mỗi lượt xem nên mọi
-- lượt xem sẽ phải ghi thêm vào chỉ mục (mất cập nhật HOT, chỉ mục phình). Với số video hiện tại, sắp xếp
-- trực tiếp rẻ hơn; khi lớn hơn nên dùng bảng xếp hạng tính định kỳ hoặc Redis sorted set.

CREATE INDEX IF NOT EXISTS idx_videos_topic_feed ON videos (topic_id, status, mod_status, created_at);
