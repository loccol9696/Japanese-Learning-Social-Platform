-- Đăng nhập bằng Google: chạy tay trên môi trường dùng ddl-auto=validate (prod).
-- Môi trường dev (ddl-auto=update) tự thêm các cột này.
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider varchar(20) NOT NULL DEFAULT 'LOCAL';
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub varchar(64);
CREATE UNIQUE INDEX IF NOT EXISTS uk_users_google_sub ON users (google_sub) WHERE google_sub IS NOT NULL;
