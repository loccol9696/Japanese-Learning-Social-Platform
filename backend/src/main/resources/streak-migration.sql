-- Chuỗi ngày học liên tục. Dev (ddl-auto: update) tự tạo bảng; prod (validate) phải chạy file này trước khi triển khai.
CREATE TABLE IF NOT EXISTS user_streaks (
    user_id        BIGINT PRIMARY KEY,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    last_active_date DATE,
    updated_at     TIMESTAMP
);
