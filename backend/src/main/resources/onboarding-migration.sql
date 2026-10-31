-- Câu hỏi chào mừng (trình độ + sở thích). Chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Dev (ddl-auto=update) tự thêm cột, nhưng vẫn nên chạy để backfill người dùng cũ.

ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed_at timestamp;
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_skip_count integer NOT NULL DEFAULT 0;

-- Người dùng cũ đã có trình độ VÀ ít nhất một sở thích thì coi như đã trả lời: không hỏi lại.
-- Người còn lại (thiếu trình độ hoặc sở thích) sẽ được hỏi ở lần đăng nhập kế tiếp.
UPDATE users u
SET onboarding_completed_at = now()
WHERE u.onboarding_completed_at IS NULL
  AND u.jlpt_level IS NOT NULL
  AND EXISTS (SELECT 1 FROM user_topics ut WHERE ut.user_id = u.id);
