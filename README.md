# Japanese Learning Social Platform

Nền tảng mạng xã hội hỗ trợ học tiếng Nhật. Người dùng có thể học qua video ngắn tương tác, tạo và ôn flashcard, luyện nói Shadowing, tra từ trong phụ đề và sử dụng các tính năng AI.

## Tính năng chính

- Đăng ký, đăng nhập email/Google, OTP và quản lý mật khẩu.
- Feed video theo đề xuất hoặc theo danh sách đang theo dõi.
- Phụ đề tương tác, tra từ tiếng Nhật và phân loại theo JLPT/topic/hashtag.
- Like, lưu, bình luận, follow, block và báo cáo nội dung.
- Flashcard, quiz, matching và ôn tập theo spaced repetition.
- Luyện phát âm Shadowing và chấm điểm theo từng câu.
- AI Speech-to-Text và phân tích ngữ pháp.
- Chat 1-1 realtime qua Socket.IO, dịch tin nhắn và thông báo.
- Gói subscription, quota token và thanh toán VietQR/SePay.
- Web admin cho quản lý người dùng, nội dung, báo cáo, gói dịch vụ và analytics.

## Kiến trúc repository

Đây là monorepo gồm các thành phần:

```text
frontend/       Ứng dụng Flutter cho Android, iOS và web
backend/        REST API và các dịch vụ nền bằng Spring Boot
web/            Web admin bằng React, TypeScript và Vite
vocal-service/  Dịch vụ FastAPI hỗ trợ tách giọng
docs/           Tài liệu API, thanh toán, bảo mật và vận hành
tools/          Script hỗ trợ test trên điện thoại thật
```

## Công nghệ

| Thành phần | Công nghệ |
|---|---|
| Mobile/client | Flutter, Dart |
| Web admin | React, TypeScript, Vite |
| Backend | Java 17, Spring Boot, Spring Data JPA, Maven |
| Database | PostgreSQL |
| Cache/realtime state | Redis |
| Authentication | JWT |
| Media | Cloudinary |
| AI và dịch vụ Google | Google Cloud Speech, Translate, Gemini |
| Chat realtime | Socket.IO |
| Thanh toán | VietQR và SePay |

## Yêu cầu môi trường

- Java 17
- Maven hoặc Maven Wrapper
- PostgreSQL
- Redis
- Flutter SDK và Dart SDK
- Node.js/npm nếu chạy web admin
- Các tài khoản hoặc API key tùy tính năng: Gmail SMTP, Cloudinary, Google OAuth, Google Cloud, Gemini, Firebase và SePay

## Chạy backend

1. Tạo file cấu hình từ file mẫu:

   ```powershell
   Copy-Item backend\.env.example backend\.env
   ```

2. Điền thông tin PostgreSQL, Redis, JWT và các dịch vụ bên ngoài trong `backend\.env`.

3. Khởi động backend:

   ```powershell
   cd backend
   .\mvnw.cmd spring-boot:run
   ```

Backend mặc định chạy tại:

```text
http://localhost:8080
```

Chat Socket.IO sử dụng cổng riêng, mặc định là `9092`.

### Cấu hình quan trọng

- `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`: kết nối PostgreSQL.
- `REDIS_HOST`, `REDIS_PORT`: Redis cho OTP, refresh token và rate limit.
- `JWT_SECRET`: secret tối thiểu 32 byte.
- `CLOUDINARY_*`: upload và xử lý media.
- `MAIL_USERNAME`, `MAIL_PASSWORD`: gửi email OTP.
- `GOOGLE_CLIENT_IDS`: Google OAuth.
- `GEMINI_API_KEY`: phân tích AI.
- `PAYMENT_*`, `SEPAY_WEBHOOK_KEY`: thanh toán VietQR/SePay.

Không commit file `backend\.env` hoặc bất kỳ secret nào vào repository.

## Chạy Flutter frontend

```powershell
cd frontend
flutter pub get
flutter run
```

Địa chỉ backend có thể thay đổi khi build bằng `API_BASE_URL`:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Trên Android Emulator, frontend mặc định dùng `http://10.0.2.2:8080/api/v1`.

Khi cần cấu hình chat Socket.IO riêng:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://example.com/api/v1 `
  --dart-define=SOCKET_URL=https://example.com
```

## Chạy web admin

```powershell
cd web
npm install
npm run dev
```

Các lệnh kiểm tra và build:

```powershell
npm run lint
npm run build
```

## Kiểm thử

Backend:

```powershell
cd backend
.\mvnw.cmd test
```

Flutter:

```powershell
cd frontend
flutter test
```

Đo tải các read-path của backend bằng k6:

```powershell
k6 run `
  -e BASE_URL=http://localhost:8080 `
  -e LOAD_USER=<email> `
  -e LOAD_PASSWORD=<password> `
  backend/loadtest/k6-read-paths.js
```

## API

Xem danh sách endpoint, mô tả chức năng, tham số quan trọng và phân quyền tại [docs/api.md](docs/api.md).

Base URL REST:

```text
http://localhost:8080/api/v1
```

Nhóm Speech-to-Text dùng prefix riêng:

```text
http://localhost:8080/api/speech
```

Các API yêu cầu đăng nhập sử dụng:

```http
Authorization: Bearer <access_token>
```

Project hiện chưa tích hợp Swagger/OpenAPI spec riêng; tài liệu API được tổng hợp từ các Spring Controller và URL frontend.

## Tài liệu liên quan

- [API documentation](docs/api.md)
- [Thanh toán VietQR và SePay](docs/payment.md)
- [Rà soát bảo mật và hiệu năng](docs/hardening-and-performance.md)
- [Quy trình làm việc nhóm](docs/team_workflow.md)
- [Hướng dẫn test trên điện thoại thật](tools/phone-test/README.md)
- [Backend environment template](backend/.env.example)
- [k6 load test](backend/loadtest/k6-read-paths.js)

## Test trên điện thoại thật

Để expose backend và Socket.IO qua một domain HTTPS dùng ngrok và Caddy:

```powershell
cd tools\phone-test
.\start-tunnel.ps1 -Domain <your-ngrok-domain>
.\build-apk.ps1 -Domain <your-ngrok-domain>
```

Hướng dẫn đầy đủ, bao gồm cài đặt Android SDK, ngrok, Caddy và các lỗi thường gặp, nằm tại [tools/phone-test/README.md](tools/phone-test/README.md).

## Lưu ý bảo mật

- Chỉ dùng secret/API key trong file `.env` hoặc secret manager của môi trường triển khai.
- Production cần cấu hình `CORS_ALLOWED_ORIGINS` cụ thể, không dùng wildcard.
- Webhook SePay phải dùng `Authorization: Apikey <SEPAY_WEBHOOK_KEY>`.
- Không bật các chế độ debug hoặc diagnostics hiệu năng trong môi trường production nếu không cần thiết.
