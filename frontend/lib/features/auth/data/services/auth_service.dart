import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthService {
  static AuthService? _instance;
  AuthService._();
  static AuthService get instance => _instance ??= AuthService._();

  final ApiClient _apiClient = ApiClient.instance;
  final TokenStorage _storage = TokenStorage.instance;

  Future<AuthResponseModel> login({
    required String usernameOrEmail,
    required String password,
    bool rememberMe = true,
  }) async {
    final responseData = await _apiClient.post(
      ApiConstants.loginUrl,
      body: {
        'usernameOrEmail': usernameOrEmail.trim(),
        'password': password,
      },
    );

    final authResponse = AuthResponseModel.fromJson(responseData as Map<String, dynamic>);

    if (authResponse.accessToken != null && authResponse.accessToken!.isNotEmpty) {
      await _storage.saveAuthData(
        accessToken: authResponse.accessToken!,
        refreshToken: authResponse.refreshToken,
        user: authResponse.user?.toJson(),
      );
    }

    await _storage.saveRememberMe(
      rememberMe: rememberMe,
      email: rememberMe ? usernameOrEmail.trim() : null,
    );

    return authResponse;
  }

  Future<AuthResponseModel> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final responseData = await _apiClient.post(
      ApiConstants.registerUrl,
      body: {
        'username': username.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'displayName': displayName?.trim().isNotEmpty == true ? displayName!.trim() : username.trim(),
      },
    );

    if (responseData is Map<String, dynamic>) {
      return AuthResponseModel.fromJson(responseData);
    }
    return const AuthResponseModel();
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    await _apiClient.post(
      ApiConstants.verifyOtpUrl,
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      },
    );
  }

  Future<void> resendOtp({
    required String email,
  }) async {
    await _apiClient.post(
      ApiConstants.resendOtpUrl,
      body: {
        'email': email.trim().toLowerCase(),
      },
    );
  }

  Future<void> logout() async {
    await _storage.clear();
  }

  Future<bool> isLoggedIn() async {
    return _storage.isLoggedIn();
  }

  Future<UserModel?> getCurrentUser() async {
    final userData = await _storage.getUserData();
    if (userData == null) return null;
    return UserModel.fromJson(userData);
  }
}
