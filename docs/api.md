# API Documentation

## Tổng quan

Backend sử dụng Spring Boot. API thông thường có prefix:

```text
http://localhost:8080/api/v1
```

Nhóm Speech-to-Text sử dụng prefix riêng:

```text
http://localhost:8080/api/speech
```

Các API yêu cầu đăng nhập sử dụng header:

```http
Authorization: Bearer <access_token>
```

Response REST thông thường có dạng `ApiResponse<T>`. Các API danh sách có phân trang thường trả về `PageResponse<T>`.

> Project hiện chưa có OpenAPI/Swagger spec riêng. Tài liệu này được tổng hợp từ các Spring Controller trong backend và các URL được frontend sử dụng.

## 1. Authentication

Controller: `backend/src/main/java/com/jlsp/backend/auth/controller/AuthController.java`

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/auth/register` | Đăng ký tài khoản và gửi OTP xác thực email. |
| POST | `/auth/login` | Đăng nhập bằng email và mật khẩu. |
| POST | `/auth/google` | Đăng nhập bằng Google ID token. |
| POST | `/auth/refresh` | Tạo access token mới từ refresh token. |
| POST | `/auth/logout` | Đăng xuất và thu hồi token nếu có. |
| POST | `/auth/verify-otp` | Xác thực tài khoản bằng OTP. |
| POST | `/auth/resend-otp` | Gửi lại OTP. |
| POST | `/auth/forgot-password` | Yêu cầu mã khôi phục mật khẩu. |
| POST | `/auth/reset-password` | Đặt lại mật khẩu bằng mã khôi phục. |
| POST | `/auth/change-password` | Đổi mật khẩu khi đã đăng nhập. |

## 2. User và Profile

Controllers:

- `backend/src/main/java/com/jlsp/backend/user/controller/UserController.java`
- `backend/src/main/java/com/jlsp/backend/user/controller/ProfileController.java`

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/users` | Admin tạo người dùng. |
| POST | `/users/admin-create` | Admin tạo tài khoản có quyền đặc biệt. |
| POST | `/users/admin-batch-create` | Admin tạo nhiều tài khoản. |
| GET | `/users/admin-list` | Admin tìm kiếm danh sách người dùng; hỗ trợ `search`, `role`, phân trang. |
| PATCH | `/users/{id}/toggle-status` | Khóa hoặc mở khóa tài khoản. |
| GET | `/users/search?q=...` | Tìm kiếm người dùng công khai. |
| GET | `/users/{id}` | Lấy thông tin người dùng theo ID. |
| GET | `/users` | Lấy danh sách người dùng dành cho admin. |
| PUT | `/users/{id}` | Cập nhật thông tin người dùng. |
| PUT | `/users/profile-by-username/{username}` | Cập nhật profile theo username. |
| DELETE | `/users/{id}` | Vô hiệu hóa tài khoản. |
| POST | `/users/{id}/follow` | Theo dõi người dùng. |
| DELETE | `/users/{id}/follow` | Bỏ theo dõi. |
| GET | `/users/me/followers` | Danh sách người đang theo dõi mình. |
| GET | `/users/me/following` | Danh sách người mình đang theo dõi. |
| GET | `/users/{id}/public-profile` | Lấy profile công khai. |
| GET | `/users/{id}/follow-status` | Kiểm tra trạng thái follow. |
| GET | `/users/{id}/videos` | Lấy video của một người dùng. |
| GET | `/profile` | Lấy profile của user hiện tại. |
| PUT | `/profile` | Cập nhật profile hiện tại. |

## 3. Block user

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/users/{id}/block` | Chặn người dùng. |
| DELETE | `/users/{id}/block` | Bỏ chặn. |
| GET | `/users/me/blocked` | Danh sách người đã chặn. |

## 4. Video

Controller: `backend/src/main/java/com/jlsp/backend/video/controller/VideoController.java`

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/videos` | Lấy feed; hỗ trợ `feed`, `jlptLevel`, `userId`, `search`, `topicIds`, phân trang. |
| POST | `/videos` | Tạo video mới. |
| GET | `/videos/{id}` | Lấy chi tiết video. |
| PUT | `/videos/{id}` | Cập nhật toàn bộ video. |
| PATCH | `/videos/{id}` | Cập nhật một phần video. |
| PATCH | `/videos/{id}/classification` | Admin/Moderator cập nhật topic, hashtag và phân loại. |
| DELETE | `/videos/{id}` | Chuyển video vào thùng rác. |
| GET | `/videos/trash` | Lấy video trong thùng rác. |
| POST | `/videos/{id}/restore` | Khôi phục video. |
| DELETE | `/videos/{id}/permanent` | Xóa video vĩnh viễn. |
| POST | `/videos/{id}/likes` | Like video. |
| DELETE | `/videos/{id}/likes` | Unlike video. |
| POST | `/videos/{id}/like` | Alias của API like. |
| POST | `/videos/{id}/saves` | Lưu video. |
| DELETE | `/videos/{id}/saves` | Bỏ lưu video. |
| POST | `/videos/{id}/save` | Alias của API lưu video. |
| POST | `/videos/{id}/views` | Ghi nhận lượt xem. |
| GET | `/videos/{id}/subtitles` | Lấy phụ đề video. |
| PUT | `/videos/{id}/subtitles` | Cập nhật phụ đề. |
| POST | `/videos/{id}/shadowing-practices` | Tạo bài luyện shadowing. |
| GET | `/videos/{id}/shadowing-practices` | Lấy bài luyện shadowing. |
| POST | `/videos/{id}/shadowing/lines/{index}/score` | Chấm điểm một câu shadowing. |
| GET | `/videos/{id}/shadowing/summary` | Lấy tổng hợp kết quả shadowing. |
| POST | `/videos/{id}/shadowing` | Nộp kết quả shadowing. |
| GET | `/videos/{id}/shadowing/history` | Lịch sử luyện shadowing. |
| GET | `/videos/feed/for-you` | Feed đề xuất. |
| GET | `/videos/feed/following` | Feed từ người đang follow. |
| GET | `/videos/user/{userId}` | Video của user. |
| GET | `/videos/liked` | Video đã thích. |
| GET | `/videos/saved` | Video đã lưu. |
| GET | `/videos/moderation` | Video chờ kiểm duyệt. |
| POST | `/videos/{id}/approve` | Duyệt video. |
| POST | `/videos/{id}/reject` | Từ chối video. |
| GET | `/videos/my-status` | Trạng thái video của user hiện tại. |

### Comment video

Controller: `backend/src/main/java/com/jlsp/backend/video/controller/VideoCommentController.java`

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/videos/{videoId}/comments` | Lấy bình luận; hỗ trợ `sort`. |
| POST | `/videos/{videoId}/comments` | Tạo bình luận. |
| DELETE | `/videos/{videoId}/comments/{commentId}` | Xóa bình luận. |
| POST | `/videos/{videoId}/comments/{commentId}/likes` | Like bình luận. |
| DELETE | `/videos/{videoId}/comments/{commentId}/likes` | Unlike bình luận. |
| POST | `/videos/{videoId}/comments/{commentId}/pin` | Ghim bình luận lên đầu (chủ video hoặc admin). |
| DELETE | `/videos/{videoId}/comments/{commentId}/pin` | Bỏ ghim bình luận (chủ video hoặc admin). |

## 5. Hashtag và Topic

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/hashtags/suggest?q=...&limit=8` | Gợi ý hashtag. |
| GET | `/topics` | Lấy topic đang hoạt động. |
| GET | `/topics/admin` | Admin xem toàn bộ topic. |
| POST | `/topics/admin` | Tạo topic. |
| PUT | `/topics/admin/{id}` | Cập nhật topic. |
| DELETE | `/topics/admin/{id}` | Ẩn topic. |

`/topics` cũng được map bởi alias `/api/v1/topics`.

## 6. Flashcard

Controller: `backend/src/main/java/com/jlsp/backend/flashcard/controller/FlashcardController.java`

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/flashcards/sets` | Danh sách bộ thẻ; hỗ trợ `search` và phân trang. |
| POST | `/flashcards/sets` | Tạo bộ thẻ. |
| GET | `/flashcards/sets/{setId}` | Chi tiết bộ thẻ. |
| POST | `/flashcards/sets/{setId}/copy` | Sao chép / lưu bộ thẻ của người khác vào thư viện của mình. |
| PUT | `/flashcards/sets/{setId}` | Cập nhật bộ thẻ. |
| DELETE | `/flashcards/sets/{setId}` | Xóa bộ thẻ. |
| PUT | `/flashcards/sets/order` | Sắp xếp các bộ thẻ. |
| PUT | `/flashcards/sets/{setId}/cards/order` | Sắp xếp thẻ trong bộ. |
| GET | `/flashcards/sets/{setId}/cards` | Lấy thẻ; hỗ trợ `starredOnly`, `shuffle`. |
| POST | `/flashcards/sets/{setId}/cards` | Thêm thẻ. |
| PUT | `/flashcards/cards/{cardId}` | Cập nhật thẻ. |
| DELETE | `/flashcards/cards/{cardId}` | Xóa thẻ. |
| POST | `/flashcards/cards/{cardId}/star` | Đánh dấu hoặc bỏ yêu thích. |
| POST | `/flashcards/study/answer` | Gửi kết quả trả lời để cập nhật spaced repetition. |
| GET | `/flashcards/sets/{setId}/study-session` | Tạo phiên học cho một bộ. |
| GET | `/flashcards/study/due-session` | Lấy thẻ đã đến hạn ôn. |
| POST | `/flashcards/study/review` | Ghi nhận phiên ôn tập. |
| GET | `/flashcards/study/due-summary` | Thống kê thẻ đến hạn. |
| GET | `/flashcards/sets/{setId}/quiz` | Tạo quiz. |
| GET | `/flashcards/sets/{setId}/matching` | Tạo trò chơi matching. |
| POST | `/flashcards/sets/{setId}/reset` | Reset tiến độ học. |
| POST | `/flashcards/video/save` | Lưu từ vựng/video thành flashcard. |

## 7. Dictionary

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/dictionary/tokenize?text=...` | Tách câu tiếng Nhật thành các từ. |
| GET | `/dictionary/lookup?word=...` | Tra cách đọc, nghĩa và cấp JLPT. |

API `lookup` có giới hạn tốc độ theo IP.

## 8. Media và Cloudinary

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/media/cloudinary-sign?folder=...` | Tạo chữ ký để frontend upload trực tiếp lên Cloudinary. |
| POST | `/media/upload` | Upload file multipart; field chính là `file`. |
| POST | `/media/youtube` | Nhập video từ URL YouTube và upload lên Cloudinary. |

## 9. Speech-to-Text và Grammar AI

Các endpoint bên dưới dùng prefix `/api/speech`, không dùng `/api/v1`.

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/api/speech/transcribe` | Upload audio/video để tạo phụ đề bất đồng bộ; trả `taskId`. |
| POST | `/api/speech/transcribe-url` | Tạo phụ đề từ URL video Cloudinary. |
| GET | `/api/speech/status/{taskId}` | Kiểm tra trạng thái `PROCESSING`, `COMPLETED`, `FAILED` hoặc `NOT_FOUND`. |
| POST | `/api/speech/analyze-grammar` | Phân tích ngữ pháp cho các đoạn phụ đề. |

Các API AI có thể trừ token theo thời lượng hoặc số lần sử dụng.

## 10. Onboarding

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/onboarding` | Lấy trạng thái onboarding. |
| PUT | `/onboarding` | Lưu trình độ và sở thích học. |
| POST | `/onboarding/skip` | Bỏ qua onboarding. |

## 11. Notification

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/notifications` | Lấy thông báo; hỗ trợ `unreadOnly`, `page`, `size`. |
| GET | `/notifications/unread-count` | Lấy số thông báo chưa đọc. |
| POST | `/notifications/{id}/read` | Đánh dấu một thông báo đã đọc. |
| POST | `/notifications/read-all` | Đánh dấu toàn bộ đã đọc. |

## 12. Streak

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/users/me/streak` | Lấy chuỗi ngày học liên tục. |
| GET | `/users/me/streak/days?from=YYYY-MM-DD&to=YYYY-MM-DD` | Lấy các ngày đã học trong khoảng thời gian. |

## 13. Chat

Chat realtime chính sử dụng Socket.IO. REST API dùng để tải dữ liệu ban đầu và làm fallback khi socket mất kết nối.

### REST Endpoints

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/chat/contacts` | Danh sách người có thể nhắn tin. |
| GET | `/chat/conversations` | Danh sách hội thoại. |
| POST | `/chat/conversations` | Mở hoặc tạo hội thoại. |
| GET | `/chat/conversations/{id}` | Lấy thông tin hội thoại. |
| DELETE | `/chat/conversations/{id}` | Xóa hội thoại ở phía user hiện tại. |
| GET | `/chat/conversations/{id}/messages` | Lịch sử tin nhắn; hỗ trợ `before`, `after`, `size`. |
| POST | `/chat/conversations/{id}/messages` | Gửi tin nhắn khi Socket.IO lỗi. |
| POST | `/chat/conversations/{id}/read` | Đánh dấu tin nhắn đã đọc. |
| GET | `/chat/unread-count` | Tổng số tin chưa đọc. |
| POST | `/chat/messages/{id}/recall` | Thu hồi tin nhắn của mình. |
| GET | `/chat/messages/{id}/translation` | Dịch tin nhắn Nhật sang Việt. |
| POST | `/chat/blocks/{userId}` | Chặn user trong chat. |
| DELETE | `/chat/blocks/{userId}` | Bỏ chặn user trong chat. |
| POST | `/chat/devices` | Đăng ký device token FCM. |
| DELETE | `/chat/devices` | Hủy đăng ký device token. |
| POST | `/videos/{id}/share` | Chia sẻ video trong chat. |
| POST | `/flashcards/sets/{id}/share` | Chia sẻ bộ flashcard trong chat. |

### Socket.IO Realtime Events

Kết nối cổng Socket.IO với access token qua query `?token=<access_token>` hoặc header `Authorization: Bearer <token>`.

- **Client → Server**:
  - `message:send`: Gửi tin nhắn realtime (`SendMessageRequest`) kèm Ack `{ok, data}`.
  - `conversation:read`: Đánh dấu đã đọc hội thoại (`MarkReadRequest`).
  - `typing`: Phát tín hiệu đang gõ tin nhắn (`TypingRequest`).
- **Server → Client**:
  - `message:new`: Nhận tin nhắn mới từ người khác.
  - `message:recalled`: Nhận thông báo một tin nhắn đã bị thu hồi.
  - `message:read`: Nhận thông báo đối phương đã đọc tin nhắn.
  - `conversation:cleared`: Nhận thông báo xóa lịch sử hội thoại.
  - `typing`: Nhận tín hiệu đối phương đang soạn tin.

## 14. Báo cáo và kiểm duyệt

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/reports` | User gửi báo cáo nội dung hoặc người dùng. |
| GET | `/admin/reports` | Admin/Moderator xem danh sách báo cáo. |
| POST | `/admin/reports/{id}/resolve` | Đánh dấu báo cáo đã xử lý. |
| POST | `/admin/reports/{id}/dismiss` | Bỏ qua báo cáo. |

## 15. Subscription và Payment

### Người dùng

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/payments/orders` | Tạo đơn thanh toán. |
| GET | `/payments/orders/{orderCode}` | Xem chi tiết đơn của mình. |
| GET | `/payments/orders` | Xem lịch sử đơn hàng. |
| GET | `/payments/my-subscription` | Xem gói subscription hiện tại. |
| GET | `/payments/token-usage` | Thống kê token đã dùng theo ngày và tính năng; hỗ trợ `range=week` hoặc `range=month`. |
| GET | `/payments/my-quota` | Xem quota token hiện tại. |
| GET | `/payments/token-quota` | Alias của `/payments/my-quota`. |

### Subscription plan

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/subscription-plans` | Lấy các gói đang hoạt động. |
| GET | `/subscription-plans/{id}` | Lấy chi tiết một gói. |
| POST | `/subscription-plans` | Admin tạo gói mới. |
| PUT | `/subscription-plans/{id}` | Admin cập nhật gói. |
| GET | `/subscription-plans/admin-all` | Admin xem tất cả gói (alias: `/subscription-plans/admin/all`). |
| POST | `/subscription-plans/admin` | Alias tạo gói cho admin. |
| PUT | `/subscription-plans/admin/{id}` | Alias cập nhật gói cho admin. |
| DELETE | `/subscription-plans/admin/{id}` | Ẩn gói subscription. |
| GET | `/subscription-plans/token-rate` | Xem tỷ lệ quy đổi token (alias: `/subscription-plans/admin/token-rate`). |
| PUT | `/subscription-plans/token-rate` | Cập nhật tỷ lệ quy đổi token (alias: `/subscription-plans/admin/token-rate`). |

### Webhook và admin payment

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/payments/webhook/sepay` | Nhận webhook biến động số dư từ SePay; dùng `Authorization: Apikey <key>`. |
| GET | `/admin/payments` | Admin xem danh sách thanh toán. |
| POST | `/admin/payments/{orderCode}/confirm` | Admin xác nhận đơn thanh toán. |

## 16. Admin Analytics và Subtitle

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/admin/analytics` | Thống kê tổng quan; `period` mặc định là `7days`. |
| GET | `/admin/analytics/trend` | Xu hướng user/token/order theo ngày; hỗ trợ `metric`, `period`, `year`, `month`, `startDate`, `endDate`. |
| POST | `/admin/subtitles/resplit` | Tách lại phụ đề dài; hỗ trợ `videoId`, `dryRun`, mặc định `dryRun=true`. |

## Phân quyền chính

Theo `backend/src/main/java/com/jlsp/backend/common/config/SecurityConfig.java`:

- API đăng ký, đăng nhập, refresh token, OTP, reset password và webhook thanh toán là public.
- Một số API GET video, topic, hashtag, dictionary và subscription plan là public.
- `/admin/**` yêu cầu quyền `ADMIN`.
- API kiểm duyệt video và xử lý report yêu cầu `ADMIN` hoặc `MODERATOR`.
- API tạo, sửa và xóa dữ liệu cá nhân yêu cầu đăng nhập.
- Danh tính người dùng chủ yếu được lấy từ access token, không nhận `userId` từ request để hạn chế truy cập dữ liệu của người khác.
