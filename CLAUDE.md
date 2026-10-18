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
- Lỗi nghiệp vụ: ném `AppException(ErrorCode.X)` hoặc `AppException(ErrorCode.X, "message riêng")` (`ResourceNotFoundException` cho 404), để `GlobalExceptionHandler` map ra `ApiResponse`; không tự build response lỗi trong controller. Lỗi không lường trước trả 500 với message chung (chi tiết chỉ nằm trong log).
- Không "fallback" âm thầm khi thiếu dữ liệu (user/gói đầu tiên trong DB, giá trị mặc định thay cho input sai) → ném `AppException`. Request DTO dùng Bean Validation + `@Valid`; DTO cho PATCH chỉ dùng ràng buộc cho phép `null` (`@Size(min = 1)`).
- Seed data: `src/main/resources/data.sql` + `common/config/DataInitializer`.
- `application.yml` nằm trong `backend/.gitignore` nhưng **vẫn đang được git track** → đừng `git add` thay đổi local của nó; mẫu cấu hình ở `application.yml.txt`.
- `BackendApplicationTests` (context load) kết nối DB thật theo `application.yml` (profile `dev` trỏ tới DB dùng chung, `ddl-auto: update`) → **đừng chạy nó trên máy dev**. Chạy mọi test còn lại (không cần DB): `./mvnw test -Dtest='!BackendApplicationTests' -Dsurefire.failIfNoSpecifiedTests=false`.
- Thêm/sửa `@Query`: `AggregateQueryValidationTest` (`@DataJpaTest`, datasource giả, `allow_jdbc_metadata_access=false`) validate cú pháp HQL mà không cần DB.
- Thống kê/báo cáo: gom nhóm trong DB (`COUNT/SUM ... GROUP BY`, projection như `common/projection/DailyTotal`), không `findAll()` rồi lọc bằng stream.
- Endpoint cũ giữ để tương thích: `@Deprecated` + header `Deprecation`/`Link` (xem `VideoController#deprecated`), xóa ở bản sau.

## Frontend (`frontend/lib/`)

- `app/` (app.dart, `routes.dart`), `core/` (constants/`api_constants.dart`, network/`api_client.dart`, storage/`token_storage.dart`, theme/`app_colors.dart`, localization).
- Feature theo lớp: `features/<feature>/{data/..., domain/..., presentation/{screens,widgets}}`. `home`/`profile` có đủ datasource + repository + domain; `auth`/`flashcard` dùng dạng gọn `data/{models,services}` + `presentation/` (chỉ thêm domain/repository khi thực sự cần mock/thay nguồn dữ liệu).
- **Mọi HTTP request đi qua `core/network/ApiClient`** (gắn JWT, timeout, bóc `data`, lỗi → `ApiException`; có `postMultipart`). Không import `package:http` trong feature. Test dùng `ApiClient.withClient(MockClient(...), tokenProvider: ...)`.
- Điều hướng chính: `HomeScreen` có bottom nav — index 0 feed, 1 `DeckLibraryScreen` (Flashcard), 4 `ProfileScreen`.
- URL API khai báo trong `ApiConstants`: `serverUrl` tự chọn host theo platform (Android emulator → `10.0.2.2:8080`), `baseUrl` = `serverUrl/api/v1`. Speech-to-Text nằm ngoài `/v1` (`/api/speech/...`) → dùng `ApiConstants.speechStatusUrl`. Request cần đăng nhập dùng `withAuth: true` (mặc định với get/put/delete/postMultipart; `post` mặc định `false` cho các API auth).
- `file_picker` ≥ 13: dùng `FilePicker.pickFile(...)` + `PlatformFile.readAsBytes()` (API `FilePicker.platform`, `withData`, `.bytes` đã bị bỏ).
- Lint: `flutter_lints`. Dùng `Color.withValues(alpha: ...)` (không dùng `withOpacity`).
- Màu thương hiệu ở `AppColors`; màn Profile dùng dark TikTok-style (`#121212` nền, `#1E1F28` surface, `#20D5EC` cyan, `#FE2C55` đỏ, `#8E8E93` text phụ).
- Profile hiện dùng mock data cục bộ (chưa nối API danh sách video/saved; BE chưa có `GET` danh sách video đã lưu).
- **Code chỉ chạy trên web** (`dart:html`, `dart:js_interop`) phải tách bằng conditional export: file chính `export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart';` (xem `core/services/tts_service.dart`, `profile_storage.dart`). Import trực tiếp sẽ làm `flutter test` (chạy trên VM) không compile được.

## Web admin (`web/src/`)

- `components/AdminDashboard.tsx` chỉ là khung (sidebar, header, toast, chọn tab). Mỗi tab là một component trong `components/admin/` nhận `AdminTabProps` (`isActive`, `showToast`, `actionsSlot`, `modalsSlot`).
- Tab luôn được mount (giữ state khi chuyển tab) và `return null` khi không active; nút trên header và modal render qua `createPortal` vào `actionsSlot` / `modalsSlot` để giữ đúng vị trí DOM.
- Mọi gọi API trong `services/adminService.ts` qua `apiFetch` (401 → tự đăng xuất). Biểu đồ: `admin/charts.tsx`, `TrendChartCard` + `useMetricTrend`.

## Ngôn ngữ

UI string và comment chủ yếu bằng tiếng Việt — giữ nguyên phong cách đó.
