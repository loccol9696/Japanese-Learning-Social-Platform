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
- Lỗi nghiệp vụ: ném `AppException(status, message)` / `ResourceNotFoundException`, để `GlobalExceptionHandler` map ra `ApiResponse`; không tự build response lỗi trong controller.
- Seed data: `src/main/resources/data.sql` + `common/config/DataInitializer`.
- `application.yml` nằm trong `backend/.gitignore` nhưng **vẫn đang được git track** → đừng `git add` thay đổi local của nó; mẫu cấu hình ở `application.yml.txt`.
- Test BE hiện chỉ có `BackendApplicationTests` (context load) → cần PostgreSQL + Redis chạy sẵn.

## Frontend (`frontend/lib/`)

- `app/` (app.dart, `routes.dart`), `core/` (constants/`api_constants.dart`, network/`api_client.dart`, storage/`token_storage.dart`, theme/`app_colors.dart`, localization).
- Feature theo lớp: `features/<feature>/{data/{datasources,models,repositories}, domain/{models,repositories}, presentation/{screens,widgets}}`. (`auth` dùng cấu trúc cũ phẳng hơn.)
- Điều hướng chính: `HomeScreen` có bottom nav — index 0 feed, 1 `DeckLibraryScreen` (Flashcard), 4 `ProfileScreen`.
- Base URL API tự chọn theo platform trong `ApiConstants.baseUrl` (Android emulator → `10.0.2.2:8080`).
- Lint: `flutter_lints`. Dùng `Color.withValues(alpha: ...)` (không dùng `withOpacity`).
- Màu thương hiệu ở `AppColors`; màn Profile dùng dark TikTok-style (`#121212` nền, `#1E1F28` surface, `#20D5EC` cyan, `#FE2C55` đỏ, `#8E8E93` text phụ).
- Profile hiện dùng mock data cục bộ (chưa nối API danh sách video/saved; BE chưa có `GET` danh sách video đã lưu).
- **Lỗi đã biết:** `core/services/tts_service.dart` import `dart:js_interop` trực tiếp → mọi test kéo theo `HomeScreen` (`test/widget_test.dart`, `home_screen_test.dart`) không compile trên VM. Cần conditional import (như `profile_storage_stub/web`) để sửa.

## Ngôn ngữ

UI string và comment chủ yếu bằng tiếng Việt — giữ nguyên phong cách đó.
