-- Làm lại thanh toán mua gói (VietQR + SePay). Chạy tay trên môi trường dùng ddl-auto=validate (prod);
-- môi trường dev (ddl-auto=update) tự thêm cột và bảng, nhưng vẫn nên chạy dòng "verification_code" và "version".

-- Đơn: mã chuyển khoản, hạn thanh toán, số tiền đã nhận, truy vết duyệt tay, khoá lạc quan.
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS transfer_memo varchar(32);
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS expires_at timestamp;
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS paid_amount numeric(38, 2);
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS bank_transaction_id varchar(64);
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS confirmed_by bigint;
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS note varchar(255);
ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS version bigint NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX IF NOT EXISTS uk_subscription_orders_transfer_memo ON subscription_orders (transfer_memo);

-- Mã xác nhận cũ (kiểu mô phỏng QR) không còn dùng; đơn mới không có.
ALTER TABLE subscription_orders ALTER COLUMN verification_code DROP NOT NULL;

-- Trạng thái đơn mới (EXPIRED, CANCELLED, NEEDS_REVIEW). Hibernate tạo ràng buộc CHECK liệt kê sẵn giá trị enum và
-- ddl-auto=update KHÔNG cập nhật nó, nên phải tạo lại bằng tay.
ALTER TABLE subscription_orders DROP CONSTRAINT IF EXISTS subscription_orders_status_check;
ALTER TABLE subscription_orders ADD CONSTRAINT subscription_orders_status_check
    CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'EXPIRED', 'CANCELLED', 'NEEDS_REVIEW'));

-- Sổ cái giao dịch ngân hàng: mỗi giao dịch SePay chỉ được ghi một lần (chống xử lý trùng khi webhook gửi lại).
CREATE TABLE IF NOT EXISTS payment_transactions (
    id               BIGSERIAL PRIMARY KEY,
    gateway          varchar(20)    NOT NULL,
    external_id      varchar(64)    NOT NULL,
    amount           numeric(18, 2) NOT NULL,
    account_number   varchar(32),
    content          text,
    reference_code   varchar(64),
    transaction_time varchar(32),
    order_id         bigint,
    status           varchar(20)    NOT NULL,
    created_at       timestamp      NOT NULL,
    CONSTRAINT uk_payment_tx_gateway_external UNIQUE (gateway, external_id)
);
CREATE INDEX IF NOT EXISTS idx_payment_tx_order ON payment_transactions (order_id);
