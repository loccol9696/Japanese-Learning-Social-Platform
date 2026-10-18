// Trình duyệt có cho video tự phát CÓ TIẾNG không (web: chỉ khi người dùng đã tương tác
// với trang — click/chạm/gõ phím; app native: luôn được).
export 'autoplay_policy_stub.dart'
    if (dart.library.js_interop) 'autoplay_policy_web.dart';
