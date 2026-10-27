-- Xoá cuộc trò chuyện phía người dùng. Dev (ddl-auto: update) tự thêm cột; prod (validate) phải chạy file này trước.
ALTER TABLE conversation_participants ADD COLUMN IF NOT EXISTS cleared_before_message_id BIGINT;

-- Chia sẻ bộ thẻ (tin nhắn DECK_SHARE): thêm cột deck_id và cho phép giá trị mới của cột type.
-- Hibernate tạo ràng buộc kiểm tra liệt kê sẵn các giá trị enum, nên ddl-auto: update KHÔNG tự cập nhật nó; cần chạy tay
-- ở cả dev lẫn prod, nếu không việc chèn tin DECK_SHARE sẽ bị từ chối.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deck_id BIGINT;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_type_check CHECK (type IN ('TEXT', 'VIDEO_SHARE', 'DECK_SHARE'));
