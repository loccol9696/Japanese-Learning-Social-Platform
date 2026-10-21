import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Gọi các API xác thực. Trạng thái đăng nhập dùng chung cho UI nằm ở
/// `AuthSession`; màn hình nên gọi qua `AuthSession` thay vì gọi thẳng đây.
class AuthService {
  static AuthService? _instance;
  AuthService._();
  static AuthService get instance => _instance ??= AuthService._();

  ApiClient get _api => ApiClient.instance;
  final TokenStorage _storage = TokenStorage.instance;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<AuthResponseModel> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final data = await _api.post(
      ApiConstants.loginUrl,
      body: {'usernameOrEmail': normalizedEmail, 'password': password},
      withAuth: false,
    );
    final auth = AuthResponseModel.fromJson(data as Map<String, dynamic>);
    await _saveSession(auth);
    await _storage.saveRememberMe(
      rememberMe: rememberMe,
      email: rememberMe ? normalizedEmail : null,
    );
    return auth;
  }

  Future<AuthResponseModel> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await _api.post(
      ApiConstants.registerUrl,
      body: {
        'username': username.trim(),
        'email': normalizeEmail(email),
        'password': password,
        'displayName': displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : username.trim(),
      },
      withAuth: false,
    );
    return data is Map<String, dynamic>
        ? AuthResponseModel.fromJson(data)
        : const AuthResponseModel();
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    await _api.post(
      ApiConstants.verifyOtpUrl,
      body: {'email': normalizeEmail(email), 'otp': otp.trim()},
      withAuth: false,
    );
  }

  Future<void> resendOtp({required String email}) async {
    await _api.post(
      ApiConstants.resendOtpUrl,
      body: {'email': normalizeEmail(email)},
      withAuth: false,
    );
  }

  /// Server luôn trả cùng một thông báo dù email có tồn tại hay không.
  Future<void> forgotPassword({required String email}) async {
    await _api.post(
      ApiConstants.forgotPasswordUrl,
      body: {'email': normalizeEmail(email)},
      withAuth: false,
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      ApiConstants.resetPasswordUrl,
      body: {
        'email': normalizeEmail(email),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
      withAuth: false,
    );
  }

  /// Đổi mật khẩu: server đăng xuất các thiết bị khác và cấp token mới cho
  /// thiết bị này.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final data = await _api.post(
      ApiConstants.changePasswordUrl,
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    if (data is Map<String, dynamic>) {
      await _saveSession(AuthResponseModel.fromJson(data));
    }
  }

  /// Thu hồi phiên trên server (nếu được) rồi luôn xoá phiên cục bộ.
  Future<void> logout() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    try {
      await _api.post(
        ApiConstants.logoutUrl,
        body: {'refreshToken': ?refreshToken},
        withAuth: false,
        bearerToken: accessToken,
      );
    } catch (_) {
      // Server không phản hồi vẫn phải đăng xuất được trên máy.
    }
    await _storage.clear();
    FlashcardStore.instance.invalidateAll();
  }

  Future<UserModel?> getCurrentUser() async {
    final userData = await _storage.getUserData();
    if (userData == null) return null;
    return UserModel.fromJson(userData);
  }

  Future<void> _saveSession(AuthResponseModel auth) async {
    final access = auth.accessToken;
    final refresh = auth.refreshToken;
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      throw StateError('Máy chủ không trả về token đăng nhập');
    }
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    if (auth.user != null) await _storage.saveUser(auth.user!.toJson());
    FlashcardStore.instance.invalidateAll();
  }
}
