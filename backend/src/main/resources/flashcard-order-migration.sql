-- Sắp xếp thủ công bộ thẻ trong thư viện và thẻ trong bộ (kéo thả). Cột null = chưa từng được sắp xếp:
-- bộ mới hiện trên cùng, thẻ mới nằm cuối bộ. ddl-auto: update tự thêm cột ở dev; prod chạy tay file này.
ALTER TABLE flashcard_sets ADD COLUMN IF NOT EXISTS sort_order INTEGER;
ALTER TABLE flashcards ADD COLUMN IF NOT EXISTS sort_order INTEGER;
