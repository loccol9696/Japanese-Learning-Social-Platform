-- Thống kê token AI theo tính năng và theo ngày (trang "Token AI" trong Cài đặt).
-- Dev (ddl-auto: update) tự tạo bảng; prod (validate) phải chạy file này trước.
-- user_daily_token_usage vẫn là nguồn để kiểm hạn mức; bảng này chỉ ghi lại từng lần trừ để thống kê.
CREATE TABLE IF NOT EXISTS token_usage_events (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    feature    VARCHAR(30)  NOT NULL,
    tokens     INTEGER      NOT NULL,
    usage_date DATE         NOT NULL,
    created_at TIMESTAMP(6) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_token_events_user_date ON token_usage_events (user_id, usage_date);
