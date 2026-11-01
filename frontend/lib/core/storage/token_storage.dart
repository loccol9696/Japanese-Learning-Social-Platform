import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu phiên đăng nhập.
///
/// - Access token và refresh token nằm trong [FlutterSecureStorage]
///   (Keychain / Keystore; trên web được mã hoá trước khi lưu).
/// - Thông tin không bí mật (hồ sơ rút gọn, "ghi nhớ đăng nhập", email đã lưu)
///   nằm trong SharedPreferences.
///
/// Token được giữ thêm trong bộ nhớ để mỗi request không phải đọc lại storage.
class TokenStorage {
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserData = 'auth_user_data';
  static const String _keyRememberMe = 'auth_remember_me';
  static const String _keySavedEmail = 'auth_saved_email';

  /// Khoá cũ (token từng lưu dạng văn bản thường trong SharedPreferences).
  static const List<String> _legacyPrefKeys = [
    'jwt_access_token',
    'jwt_refresh_token',
  ];

  static TokenStorage? _instance;
  static TokenStorage get instance => _instance ??= TokenStorage._();
  TokenStorage._();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _accessToken = await _secure.read(key: _keyAccessToken);
    _refreshToken = await _secure.read(key: _keyRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyPrefKeys) {
      await prefs.remove(key);
    }
    _loaded = true;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secure.write(key: _keyAccessToken, value: accessToken);
    await _secure.write(key: _keyRefreshToken, value: refreshToken);
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(user));
  }

  Future<String?> getAccessToken() async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    await _ensureLoaded();
    return _refreshToken;
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyUserData);
    if (data == null || data.isEmpty) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// ID người dùng đã lưu — chỉ dùng cho giao diện (vd. đường dẫn hồ sơ),
  /// KHÔNG gửi lên server để chứng minh danh tính.
  Future<int?> getUserId() async {
    final id = (await getUserData())?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  /// Có phiên đăng nhập (refresh token) hay không — access token có thể đã
  /// hết hạn nhưng vẫn làm mới được.
  Future<bool> hasSession() async {
    await _ensureLoaded();
    return _refreshToken != null && _refreshToken!.isNotEmpty;
  }

  /// Đọc claim `exp` của JWT. [skew] coi token sắp hết hạn như đã hết hạn để
  /// làm mới trước. Token không đọc được thì để server quyết định.
  static bool isTokenExpired(String token, {Duration skew = Duration.zero}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().add(skew).isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  Future<void> saveRememberMe({required bool rememberMe, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, rememberMe);
    if (rememberMe && email != null) {
      await prefs.setString(_keySavedEmail, email);
    } else {
      await prefs.remove(_keySavedEmail);
    }
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedEmail);
  }

  /// Xoá phiên đăng nhập (giữ lại lựa chọn "ghi nhớ" và email đã lưu).
  Future<void> clear() async {
    await _secure.delete(key: _keyAccessToken);
    await _secure.delete(key: _keyRefreshToken);
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserData);
  }
}
