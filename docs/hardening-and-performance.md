# Rà soát bảo mật & hiệu năng (6 tuần)

Tài liệu tóm tắt đợt rà soát/tối ưu toàn hệ thống, cách đo hiệu năng và danh sách việc còn lại.

## 1. Đã làm

| Mảng | Thay đổi chính |
|---|---|
| Auth | Thu hồi access token theo người dùng (marker Redis `auth:revoked-before:{id}`); giới hạn tần suất theo IP cho login/register/OTP/refresh (`AuthRateLimitFilter`); mật khẩu mạnh (`@StrongPassword`); tạo admin đầu tiên qua biến môi trường; CORS cấu hình theo môi trường; ma trận test phân quyền (`SecurityMatrixTest`). |
| Video | Chỉ mục feed / theo người đăng / theo chủ đề; bình luận nạp theo lô (hết N+1); đếm view chống lặp 30 phút; sửa nội dung video công khai thì quay về chờ duyệt; kiểm tra loại file, dung lượng, thư mục khi upload. |
| Flashcard | Sửa lỗ hổng đọc/ghi bộ thẻ riêng tư của người khác; đếm số thẻ theo lô; giới hạn 2000 thẻ/bộ, 100 câu quiz, 20 cặp ghép; chống tạo trùng khi lưu từ video. |
| Chat/Thông báo | `ChatRateLimiter` dọn bộ nhớ người ngừng gửi; job dọn thông báo cũ lúc 03:30; chấm đỏ chưa đọc ở tab Cá nhân. |
| Social | Danh sách follower/following phân trang (tối đa 500); quan hệ follow tra theo lô; tối đa 20 báo cáo/giờ/người. |
| Từ điển | Timeout 3s/6s cho Jisho/MyMemory; cache LRU 5000 mục; 120 lượt tra/phút/IP; từ dài quá 50 ký tự không gửi ra ngoài. |
| Thống kê admin | `AdminAnalyticsService` gộp ở DB (GROUP BY theo ngày) thay vì `findAll()` ~10 lần mỗi request. |
| Web admin | Tự đăng xuất khi token hết hạn/bị thu hồi (`services/session.ts`); đọc JSON an toàn khi server trả HTML/429. |

## 2. Cách đo hiệu năng

1. Chạy backend với `APP_DIAGNOSTICS_QUERY_COUNT=true` (xem `backend/.env.example`). Mỗi request `/api/**` ghi một dòng
   `[query-count]` và trả header `X-Query-Count`, `X-Response-Time-Ms`.
2. Cài [k6](https://k6.io) rồi chạy:

   ```
   k6 run -e BASE_URL=http://localhost:8080 -e LOAD_USER=<user> -e LOAD_PASSWORD='<mật khẩu>' backend/loadtest/k6-read-paths.js
   ```

   Script đăng nhập một lần (login bị giới hạn 30 lần/5 phút/IP), sau đó đo feed, bình luận, flashcard, tìm người dùng,
   danh sách follower và thông báo. Ngưỡng p95 nằm trong `options.thresholds`.
3. Dùng dữ liệu đủ lớn (hàng nghìn video/bình luận/thẻ) thì con số mới có ý nghĩa; DB rỗng sẽ không lộ N+1.
4. So sánh số truy vấn/request và p95 giữa commit trước và sau đợt này (`git checkout bc28b08~N`) để lấy số liệu trước/sau.

**Chưa có số đo thật:** đợt rà soát được làm khi không có DB/server, nên các con số trước/sau chưa được ghi lại.

## 3. Cần kiểm chứng khi có DB

- Các câu `@Query` mới (thống kê admin: `year()/month()/day()` + `GROUP BY`, follow theo lô) chưa được Hibernate kiểm
  tra thật. Khởi động backend một lần; nếu HQL sai app sẽ không lên.
- Chỉ mục mới của video nằm ở `backend/src/main/resources/video-indexes-migration.sql`: ở prod (`ddl-auto: validate`)
  phải chạy tay.
- Tìm người dùng dùng `LIKE '%q%'` (không dùng được chỉ mục thường). Khi dữ liệu lớn: `CREATE EXTENSION pg_trgm` và GIN
  index trên `lower(username)`, `lower(display_name)`.

## 4. Việc còn lại cần quyết định

- Phát hiện dùng lại refresh token (cần chọn khoảng ân hạn khi mạng chập chờn).
- Cột `emailVerified` (đổi schema) để xử lý ghi đè đăng ký đang chờ xác thực.
- Hai bộ lập lịch ôn tập (Leitner `/study/answer` và SRS `/study/review`) cùng ghi `nextReviewAt`: chọn một.
- Múi giờ: server dùng `LocalDateTime`; nên đặt `TZ=Asia/Ho_Chi_Minh` khi chạy container.
- Chạy nhiều instance: Socket.IO cần Redis pub/sub.
- `GET /users/{id}/public-profile` được mở công khai ở `SecurityConfig` nhưng controller yêu cầu đăng nhập.
- Token web admin vẫn ở `localStorage`; hướng đúng là cookie httpOnly (cần đổi backend).

## 5. Cần đồng đội đồng ý (file ngoài phạm vi đã được giao)

- `pom.xml`: Flyway, springdoc, jacoco, Actuator, Testcontainers.
- `application.yml`: `spring.vocal-service.url` còn trỏ URL ngrok cá nhân.
- `pubspec.yaml`: `cached_network_image`.

## 6. Bàn giao cho các mảng của đồng đội (chưa sửa)

**Thanh toán / gói đăng ký**
- `/payments/confirm` đang mở; app còn VIP giả lập; chưa có job hết hạn VIP.
- Frontend `subscription_service.dart` tự gắn header `Authorization`, không qua `ApiClient` (không tự refresh token).

**AI / STT / hạn mức**
- `duration` để tính token do client gửi lên nên có thể khai thấp.
- `/media/upload` chạy STT mà không tính hạn mức.
- `SpeechToTextService` giữ trạng thái/kết quả task trong `ConcurrentHashMap` không TTL; `/api/speech/status/{taskId}`
  không kiểm tra chủ sở hữu; lỗi trả thẳng `e.getMessage()`.
- `vocal-service`: chưa xác thực, nguy cơ path traversal, file tạm không được dọn.
