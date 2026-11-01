-- Thông báo "bình luận được thích" (COMMENT_LIKED), "video được lưu" (VIDEO_SAVED), "video được chia sẻ" (VIDEO_SHARED).
-- Hibernate tạo CHECK liệt kê sẵn các giá trị enum và ddl-auto: update KHÔNG cập nhật lại; nếu còn ràng buộc này,
-- việc chèn loại mới bị từ chối và thông báo bị bỏ qua trong im lặng. NotificationSchemaUpdater cũng gỡ nó mỗi lần
-- khởi động; prod (validate) chạy tay file này một lần.
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Loại COMMENT_HEARTED (chủ video thả tim) đã bị bỏ khỏi enum. Nếu môi trường nào từng tạo thông báo loại này thì phải
-- xoá, nếu không Hibernate sẽ lỗi khi đọc giá trị enum không còn tồn tại. Không có dòng nào thì lệnh không làm gì.
DELETE FROM notifications WHERE type = 'COMMENT_HEARTED';
