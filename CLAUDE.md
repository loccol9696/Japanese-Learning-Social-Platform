# CLAUDE.md

Japanese Learning Social Platform — mạng xã hội video ngắn kết hợp học tiếng Nhật (Flashcard, Shadowing, AI script).

## Monorepo

| Thư mục | Stack | Lệnh chính (chạy trong thư mục đó) |
|---|---|---|
| `backend/` | Spring Boot, Java 17, Maven, JPA, Lombok, PostgreSQL, Redis (OTP), Cloudinary | `./mvnw spring-boot:run`, `./mvnw test` |
| `frontend/` | Flutter (mobile app chính) | `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run` |
| `web/` | React 19 + Vite + TS (admin web) | `npm run dev`, `npm run build`, `npm run lint` (oxlint) |
| `vocal-service/` | Python (`app.py`) — tách giọng cho Speech-to-Text | |
| `docs/` | `team_workflow.md`, `ui_design.md`, mockups | |

## Quy trình nhóm (xem `docs/team_workflow.md`)

- Commit: `[FE] ...` / `[BE] ...` (tiếng Việt OK). PR vào `develop`/`dev`, cần 1 approve.
- **Vùng cấm — hỏi trước khi sửa:** `frontend/pubspec.yaml`, `frontend/lib/main.dart`, `backend/pom.xml`, `backend/src/main/resources/application.yml`.

## Backend (`backend/src/main/java/com/jlsp/backend/`)

- Chia theo domain: `auth, user, video, flashcard, lesson, subscription, media, googlestt, otp, admin`.
- Mỗi module: `controller/`, `dto/request/`, `dto/response/`, `entity/`, `repository/`, `service/` (interface) + `service/impl/`, `mapper/`.
- Dùng chung trong `common/`: `config/` (Security, CORS, Cloudinary…), `security/jwt/`, `response/ApiResponse<T>` & `PageResponse`, `exception/` (`AppException` + `ErrorCode`, `GlobalExceptionHandler`), `constant/`.
- Endpoint REST prefix `/api/v1/...`; controller luôn trả `ResponseEntity<ApiResponse<T>>` qua `ApiResponse.success(...)`.
- **Danh tính người dùng chỉ lấy từ JWT** qua `common/security/CurrentUser`: `requireId()` cho endpoint ghi (401 nếu chưa đăng nhập), `idOrNull()` cho endpoint đọc công khai. **Không** nhận user id từ header (`X-User-Id`), query param hay body, không fallback về user mặc định.
- `JwtAuthenticationFilter` chạy ở mọi profile; principal là `CustomUserDetails` (nạp từ DB, tài khoản bị khóa không xác thực được). `app.security.enabled=false` (dev) chỉ tắt chặn theo URL; phân quyền theo URL/role nằm trong `SecurityConfig` (prod). Test phân quyền: `src/test/.../common/security/*Test` (`@WebMvcTest`, không cần DB).
- Lỗi nghiệp vụ: ném `AppException(status, message)` / `ResourceNotFoundException`, để `GlobalExceptionHandler` map ra `ApiResponse`; không tự build response lỗi trong controller.
- Seed data: `src/main/resources/data.sql` + `common/config/DataInitializer`.
- `application.yml` nằm trong `backend/.gitignore` nhưng **vẫn đang được git track** → đừng `git add` thay đổi local của nó; mẫu cấu hình ở `application.yml.txt`.
- `BackendApplicationTests` (context load) cần PostgreSQL + Redis chạy sẵn; chạy riêng test không cần DB: `./mvnw test -Dtest="SecurityRulesTest,DevModeIdentityTest"`.

## Frontend (`frontend/lib/`)

- `app/` (app.dart, `routes.dart`), `core/` (constants/`api_constants.dart`, network/`api_client.dart`, storage/`token_storage.dart`, theme/`app_colors.dart`, localization).
- Feature theo lớp: `features/<feature>/{data/{datasources,models,repositories}, domain/{models,repositories}, presentation/{screens,widgets}}`. (`auth` dùng cấu trúc cũ phẳng hơn.)
- Điều hướng chính: `HomeScreen` có bottom nav — index 0 feed, 1 `DeckLibraryScreen` (Flashcard), 4 `ProfileScreen`.
- URL API khai báo trong `ApiConstants`: `serverUrl` tự chọn host theo platform (Android emulator → `10.0.2.2:8080`), `baseUrl` = `serverUrl/api/v1`. Speech-to-Text nằm ngoài `/v1` (`/api/speech/...`) → dùng `ApiConstants.speechStatusUrl`. Mọi request cần đăng nhập gửi `Authorization: Bearer <token>` (`ApiClient` hoặc `TokenStorage`).
- `file_picker` ≥ 13: dùng `FilePicker.pickFile(...)` + `PlatformFile.readAsBytes()` (API `FilePicker.platform`, `withData`, `.bytes` đã bị bỏ).
- Lint: `flutter_lints`. Dùng `Color.withValues(alpha: ...)` (không dùng `withOpacity`).
- Màu thương hiệu ở `AppColors`; màn Profile dùng dark TikTok-style (`#121212` nền, `#1E1F28` surface, `#20D5EC` cyan, `#FE2C55` đỏ, `#8E8E93` text phụ).
- Profile hiện dùng mock data cục bộ (chưa nối API danh sách video/saved; BE chưa có `GET` danh sách video đã lưu).
- **Code chỉ chạy trên web** (`dart:html`, `dart:js_interop`) phải tách bằng conditional export: file chính `export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart';` (xem `core/services/tts_service.dart`, `profile_storage.dart`). Import trực tiếp sẽ làm `flutter test` (chạy trên VM) không compile được.

## Ngôn ngữ

UI string và comment chủ yếu bằng tiếng Việt — giữ nguyên phong cách đó.
