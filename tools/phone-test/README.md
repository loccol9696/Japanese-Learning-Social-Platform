# Test app trên điện thoại thật qua ngrok

Điện thoại gọi tới backend đang chạy trên máy bạn qua một tên miền ngrok. Chat realtime (Socket.IO, cổng 9092)
đi chung đường hầm nhờ Caddy gộp hai cổng thành một.

```
điện thoại ─► ngrok (tên miền tĩnh, HTTPS) ─► Caddy :8000 ─┬─ /socket.io/* ─► localhost:9092 (chat)
                                                            └─ còn lại      ─► localhost:8080 (API)
```

## Cài một lần

1. **Android SDK** (để build APK): cài Android Studio, mở lần đầu cho nó tải SDK, rồi
   `flutter doctor --android-licenses` và nhận hết điều khoản. `flutter doctor` phải báo Android toolchain màu xanh.
2. **Caddy**: `winget install Caddy.Caddy` (mở lại terminal để nhận PATH).
3. **ngrok**: `winget install ngrok.ngrok`, đăng ký tài khoản ngrok, rồi `ngrok config add-authtoken <token>`.
4. **Tên miền tĩnh miễn phí**: trên trang quản lý ngrok vào *Domains* và tạo một tên miền, dạng `ten-cua-ban.ngrok-free.app`.
   Dùng tên miền tĩnh thì APK build một lần dùng mãi.

## Mỗi lần test

1. Chạy backend (Spring Boot) như bình thường: API cổng 8080, chat cổng 9092.
2. Mở đường hầm:
   ```powershell
   .\start-tunnel.ps1 -Domain ten-cua-ban.ngrok-free.app
   ```
   Giữ cửa sổ này mở. Ctrl+C để dừng (Caddy cũng dừng theo).
3. Build APK (chỉ cần khi đổi tên miền hoặc sửa app):
   ```powershell
   .\build-apk.ps1 -Domain ten-cua-ban.ngrok-free.app
   ```
   File ra ở `frontend\build\app\outputs\flutter-apk\app-release.apk`.
4. Gửi APK sang điện thoại, bật cho phép cài từ nguồn không rõ rồi cài.

## Kiểm tra nhanh

- Mở `https://ten-cua-ban.ngrok-free.app/api/v1/...` bằng trình duyệt điện thoại: phải thấy phản hồi của backend
  (ngrok bản free có thể hiện trang cảnh báo, bấm "Visit Site").
- Trên điện thoại đăng nhập bằng email. Chat realtime: hai tài khoản nhắn nhau, tin phải hiện ngay không cần mở lại.

## Lưu ý

- Máy tính phải bật, backend và ngrok phải chạy suốt lúc test. Điện thoại chỉ cần có Internet, không cần cùng Wi-Fi.
- **Đăng nhập Google** trên Android cần tạo thêm OAuth client loại *Android* trong Google Cloud (package
  `com.example.frontend`, kèm SHA-1 của khoá ký APK). Chưa làm thì dùng đăng nhập bằng email.
- APK ký bằng khoá debug, chỉ để test, không dùng để phát hành.
- `start-tunnel.ps1` tự chọn `--url` (ngrok từ 3.16) hoặc `--domain` (bản cũ hơn, ví dụ 3.3.x do winget cài). Muốn bản mới thì chạy `ngrok update`.
- Gửi email OTP vẫn dùng Gmail theo `MAIL_USERNAME` / `MAIL_PASSWORD` trong `backend\.env`.

## Gỡ lỗi

| Hiện tượng | Nguyên nhân thường gặp |
|---|---|
| App báo lỗi kết nối ngay | Backend chưa chạy, hoặc `start-tunnel.ps1` chưa chạy, hoặc build APK bằng tên miền sai |
| API chạy nhưng chat không realtime | Build APK thiếu `SOCKET_URL` (dùng `build-apk.ps1` thì đã có), hoặc backend chưa mở cổng 9092 |
| Phản hồi là HTML của ngrok thay vì JSON | Trang cảnh báo của ngrok; thử thêm header `ngrok-skip-browser-warning` ở phía app |
| `ngrok` báo tên miền không thuộc tài khoản | Tên miền tĩnh phải do chính tài khoản đã `add-authtoken` tạo |
