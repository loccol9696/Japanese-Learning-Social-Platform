-- Học ngắt quãng (SRS): chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Môi trường dev (ddl-auto=update) tự thêm các cột này.
ALTER TABLE flashcard_progress ADD COLUMN IF NOT EXISTS ease_factor double precision NOT NULL DEFAULT 2.5;
ALTER TABLE flashcard_progress ADD COLUMN IF NOT EXISTS interval_days integer NOT NULL DEFAULT 0;
ALTER TABLE flashcard_progress ADD COLUMN IF NOT EXISTS review_count integer NOT NULL DEFAULT 0;
ALTER TABLE flashcard_progress ADD COLUMN IF NOT EXISTS lapse_count integer NOT NULL DEFAULT 0;
ALTER TABLE flashcard_progress ADD COLUMN IF NOT EXISTS srs_state varchar(16) NOT NULL DEFAULT 'NEW';
