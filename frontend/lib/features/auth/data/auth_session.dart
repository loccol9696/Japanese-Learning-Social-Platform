import 'google_auth_service.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../flashcard/data/services/flashcard_store.dart';
import 'models/auth_response_model.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Trạng thái đăng nhập dùng chung cho toàn app.
///
/// - `AuthGate` gọi [restore] khi mở app.
/// - Màn hình gọi [login] / [logout].
/// - Khi phiên hết hạn ngoài ý muốn (refresh token hết hạn / bị thu hồi),
///   [ApiClient] báo về đây và [sessionExpired] phát sự kiện để app đưa người
///   dùng về màn Đăng nhập.
class AuthSession extends ChangeNotifier {
  AuthSession._({AuthService? authService, TokenStorage? storage})
    : _authService = authService ?? AuthService.instance,
      _storage = storage ?? TokenStorage.instance {
    ApiClient.onSessionExpired = _handleSessionExpired;
  }

  static final AuthSession instance = AuthSession._();

  final AuthService _authService;
  final TokenStorage _storage;
  final StreamController<void> _expiredController =
      StreamController<void>.broadcast();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Phát mỗi lần phiên bị hết hạn (không phải do người dùng bấm đăng xuất).
  Stream<void> get sessionExpired => _expiredController.stream;

  /// Khôi phục phiên đã lưu. Khi mở app ([isAppLaunch]) mà người dùng không
  /// chọn "Ghi nhớ đăng nhập" thì đăng xuất luôn.
  Future<bool> restore({required bool isAppLaunch}) async {
    if (!await _storage.hasSession()) {
      _setUnauthenticated();
      return false;
    }
    if (isAppLaunch && !await _storage.getRememberMe()) {
      await logout();
      return false;
    }

    try {
      // Làm mới access token nếu đã hết hạn; phiên hỏng thì storage bị xoá.
      await ApiClient.instance.validAccessToken();
    } on ApiException {
      // Mất mạng: vẫn cho vào app với phiên đã lưu, request sau sẽ thử lại.
    }

    if (!await _storage.hasSession()) {
      _setUnauthenticated();
      return false;
    }
    _setAuthenticated(await _authService.getCurrentUser());
    return true;
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _authService.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    _setAuthenticated(response.user);
    return response;
  }

  Future<AuthResponseModel> loginWithGoogle(String idToken) async {
    final response = await _authService.loginWithGoogle(idToken);
    _setAuthenticated(response.user);
    return response;
  }

  Future<void> logout() async {
    await GoogleAuthService.instance.signOut();
    await _authService.logout();
    _setUnauthenticated();
  }

  void _handleSessionExpired() {
    FlashcardStore.instance.invalidateAll();
    final wasAuthenticated = _status == AuthStatus.authenticated;
    _setUnauthenticated();
    if (wasAuthenticated) _expiredController.add(null);
  }

  void _setAuthenticated(UserModel? user) {
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _setUnauthenticated() {
    final changed = _status != AuthStatus.unauthenticated || _user != null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    if (changed) notifyListeners();
  }
}
