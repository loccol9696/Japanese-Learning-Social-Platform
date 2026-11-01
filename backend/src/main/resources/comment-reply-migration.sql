-- Trả lời bình luận: lưu người được trả lời (kể cả khi trả lời một phản hồi).
-- Chạy một lần trên Supabase trước khi khởi động backend phiên bản này.

ALTER TABLE video_comments
    ADD COLUMN IF NOT EXISTS reply_to_id BIGINT REFERENCES video_comments (id) ON DELETE SET NULL;

-- Phản hồi cũ: coi như trả lời bình luận gốc (trước đây phản hồi của phản hồi cũng gắn vào gốc nên không khôi phục được).
UPDATE video_comments
SET reply_to_id = parent_id
WHERE parent_id IS NOT NULL
  AND reply_to_id IS NULL;
