import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await TokenStorage.instance.getRememberMe();
    final savedEmail = await TokenStorage.instance.getSavedEmail();
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _emailController.text = savedEmail;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      _showSnackBar('Vui lòng nhập Email', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Vui lòng nhập Mật khẩu', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.instance.login(
        usernameOrEmail: identifier,
        password: password,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      final displayName = response.user?.displayName ?? response.user?.username ?? 'bạn';
      _showSnackBar('Đăng nhập thành công! Chào mừng $displayName');

      // Navigate to Home screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      
      // If user account is not active, guide to OTP verification
      if (e.message.toLowerCase().contains('inactive') || e.message.toLowerCase().contains('activate')) {
        _showInactiveDialog(identifier);
      } else {
        _showSnackBar(e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Đã xảy ra lỗi đăng nhập. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInactiveDialog(String emailOrUsername) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Tài khoản chưa kích hoạt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tài khoản của bạn chưa được kích hoạt qua mã OTP. Bạn có muốn chuyển đến màn hình xác thực OTP không?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D1B3E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OtpVerificationScreen(email: emailOrUsername),
                ),
              );
            },
            child: const Text('Xác thực OTP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nút quay lại
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(height: 32),

              // 2. Tiêu đề Đăng nhập
              const Text(
                'Đăng nhập',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 32),

              // 3. Nhãn Email / Username
              const Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Ô nhập Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(
                  color: Color(0xFF0D1B3E),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: const Color(0xFF0D1B3E),
                decoration: InputDecoration(
                  hintText: 'name@example.com',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.mail_outline, size: 20, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D1B3E), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Nhãn Mật khẩu
              const Text(
                'Mật khẩu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Ô nhập Mật khẩu
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                style: const TextStyle(
                  color: Color(0xFF0D1B3E),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: const Color(0xFF0D1B3E),
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D1B3E), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Checkbox Ghi nhớ đăng nhập + Quên mật khẩu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: const Color(0xFF0D1B3E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ghi nhớ đăng nhập',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. Nút Đăng nhập chính
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1B3E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Đăng nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // 7. Dòng kẻ "HOẶC TIẾP TỤC VỚI"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'HOẶC TIẾP TỤC VỚI',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // 8. Nút đăng nhập Google
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          _showSnackBar('Tính năng đăng nhập Google đang phát triển', isError: false);
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/google.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 9. Dòng Đăng ký ngay
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1B3E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}