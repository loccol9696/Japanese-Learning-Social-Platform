import 'dart:convert';

/// Chính sách mật khẩu mới, khớp `@StrongPassword` của backend: từ 8 ký tự, có cả chữ và số,
/// tối đa 72 byte (BCrypt chỉ dùng 72 byte đầu). Chỉ áp dụng khi đặt mật khẩu (đăng ký, đặt lại,
/// đổi), không áp dụng khi đăng nhập để người có mật khẩu cũ ngắn hơn vẫn vào được.
const int passwordMinLength = 8;
const int passwordMaxBytes = 72;
const String passwordRuleMessage =
    'Mật khẩu phải từ $passwordMinLength đến $passwordMaxBytes ký tự, gồm cả chữ và số';

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

/// Trả về thông báo lỗi, hoặc null nếu mật khẩu mới hợp lệ.
String? validateNewPassword(String password) {
  if (password.length < passwordMinLength) {
    return 'Mật khẩu phải có ít nhất $passwordMinLength ký tự';
  }
  if (utf8.encode(password).length > passwordMaxBytes) {
    return 'Mật khẩu quá dài (tối đa $passwordMaxBytes byte)';
  }
  if (!_letter.hasMatch(password) || !_digit.hasMatch(password)) {
    return 'Mật khẩu phải gồm cả chữ và số';
  }
  return null;
}
