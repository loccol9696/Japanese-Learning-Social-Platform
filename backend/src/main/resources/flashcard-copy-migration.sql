-- Lưu bộ thẻ của người khác về thư viện của mình: nhớ bộ gốc để hiện "Đã lưu trong thư viện" và không tạo bản sao trùng.
-- Dev (ddl-auto: update) tự thêm cột; prod (validate) phải chạy file này trước.
ALTER TABLE flashcard_sets ADD COLUMN IF NOT EXISTS source_set_id BIGINT;
CREATE INDEX IF NOT EXISTS idx_flashcard_sets_user_source ON flashcard_sets (user_id, source_set_id);
