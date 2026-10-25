import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Lấy Google ID token từ thiết bị / trình duyệt. Server mới là nơi kiểm tra token và cấp phiên.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  /// OAuth Client ID loại "Web application". Đổi khi build bằng
  /// `--dart-define=GOOGLE_CLIENT_ID=...`. Trên Android/iOS đây là "server client id" để token có
  /// audience trùng với backend.
  static const String clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '173731891323-5nraiefaj1htr4jb71s7t6e3cb9mrqpu.apps.googleusercontent.com',
  );

  Future<void>? _initialization;

  Future<void> ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance
        .initialize(
          clientId: kIsWeb ? clientId : null,
          serverClientId: kIsWeb ? null : clientId,
        )
        .catchError((Object error) {
          // Cho phép thử khởi tạo lại lần sau.
          _initialization = null;
          throw error;
        });
  }

  /// Android / iOS dùng được hộp chọn tài khoản của hệ thống; web phải dùng nút do Google vẽ.
  bool get supportsNativeFlow => GoogleSignIn.instance.supportsAuthenticate();

  /// Mở hộp chọn tài khoản. Trả về null nếu người dùng đóng hộp thoại.
  Future<String?> authenticateNative() async {
    await ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Trên web, ID token đến qua luồng sự kiện sau khi người dùng bấm nút của Google.
  Stream<String> get webIdTokens {
    return GoogleSignIn.instance.authenticationEvents
        .where((event) => event is GoogleSignInAuthenticationEventSignIn)
        .map(
          (event) => (event as GoogleSignInAuthenticationEventSignIn)
              .user
              .authentication
              .idToken,
        )
        .where((token) => token != null && token.isNotEmpty)
        .cast<String>();
  }

  /// Đăng xuất khỏi Google để lần sau được chọn lại tài khoản. Lỗi được bỏ qua.
  Future<void> signOut() async {
    try {
      if (_initialization == null) return;
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
