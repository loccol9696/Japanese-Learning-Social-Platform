# Quy định Code và Git cho Japanese Learning Social Platform

## 1. Quy trình Git hàng ngày
1. Kéo code mới nhất: `git checkout develop` -> `git pull`
2. Tạo nhánh làm việc: `git checkout -b feature/ten-tinh-nang`
3. Lưu code (Commit): Cú pháp `[FE] Nội dung` hoặc `[BE] Nội dung`. 
   *Ví dụ: `git commit -m "[BE] Tạo API đăng ký"`*
4. Đẩy code: `git push origin feature/ten-tinh-nang`
5. Lên GitHub tạo Pull Request (PR) vào nhánh `develop`. Bắt buộc phải có 1 người khác Approve mới được Merge.

## 2. Vùng cấm (Cần báo cáo trước khi sửa)
- `frontend/pubspec.yaml`
- `frontend/lib/main.dart`
- `backend/pom.xml`
- `backend/src/main/resources/application.yml`

## 3. Quy tắc mở IDE (VS Code / IntelliJ)
- **Code Flutter:** Mở File > Open Folder > Chọn đúng thư mục `frontend`.
- **Code Spring Boot:** Mở File > Open Folder > Chọn đúng thư mục `backend`.
- Tuyệt đối không mở trực tiếp thư mục gốc chứa toàn bộ dự án để tránh lỗi không nhận diện được môi trường (LSP).

