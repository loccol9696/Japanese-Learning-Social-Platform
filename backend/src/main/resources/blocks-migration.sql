-- Chặn người dùng.
-- Profile dev dùng ddl-auto=update nên tự tạo; prod (validate) cần chạy script này một lần.

CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_id BIGINT    NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id BIGINT    NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_id ON user_blocks (blocked_id);
