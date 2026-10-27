-- Chuỗi ngày học liên tục. Dev (ddl-auto: update) tự tạo bảng; prod (validate) phải chạy file này trước khi triển khai.
CREATE TABLE IF NOT EXISTS user_streaks (
    user_id        BIGINT PRIMARY KEY,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    last_active_date DATE,
    updated_at     TIMESTAMP
);

-- Lịch sử các ngày đã học, dùng cho lịch chuỗi học (không có dữ liệu trước khi tính năng này ra mắt).
CREATE TABLE IF NOT EXISTS user_streak_days (
    user_id       BIGINT NOT NULL,
    activity_date DATE   NOT NULL,
    PRIMARY KEY (user_id, activity_date)
);
