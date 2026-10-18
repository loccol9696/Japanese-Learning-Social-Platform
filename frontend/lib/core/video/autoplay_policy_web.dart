import 'dart:js_interop';

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  external _UserActivation? get userActivation;
}

extension type _UserActivation(JSObject _) implements JSObject {
  external bool get hasBeenActive;
}

/// Chính sách autoplay của trình duyệt: video tự phát chỉ được có tiếng khi trang đã có
/// "user activation" (người dùng từng click/chạm/gõ phím, vd. bấm Đăng nhập). Trình duyệt
/// không hỗ trợ `navigator.userActivation` -> coi như chưa được phép (phát không tiếng).
bool canAutoplayWithSound() {
  try {
    return _navigator.userActivation?.hasBeenActive ?? false;
  } catch (_) {
    return false;
  }
}
