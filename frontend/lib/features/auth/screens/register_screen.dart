import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../data/services/auth_service.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _agreeTerms = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final displayName = _nameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showSnackBar('Vui lòng nhập Email', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Định dạng email không hợp lệ', isError: true);
      return;
    }

    if (username.isEmpty) {
      _showSnackBar('Vui lòng nhập Tên đăng nhập', isError: true);
      return;
    }

    if (username.length < 3) {
      _showSnackBar('Tên đăng nhập phải có ít nhất 3 ký tự', isError: true);
      return;
    }

    if (displayName.isEmpty) {
      _showSnackBar('Vui lòng nhập Họ và tên hiển thị', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Vui lòng nhập Mật khẩu', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Mật khẩu phải có ít nhất 6 ký tự', isError: true);
      return;
    }

    if (!_agreeTerms) {
      _showSnackBar('Vui lòng đồng ý với Điều khoản & Chính sách quyền riêng tư', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName.isNotEmpty ? displayName : username,
      );

      if (!mounted) return;

      _showSnackBar('Đăng ký thành công! Vui lòng kiểm tra mã OTP trong email.');

      // Navigate to OTP Verification Screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(email: email),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Đã xảy ra lỗi đăng ký. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Widget _buildInputField({
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: !_isLoading,
          style: const TextStyle(
            color: Color(0xFF0D1B3E),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: const Color(0xFF0D1B3E),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey),
            suffixIcon: suffixIcon,
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
      ],
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
                icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black87),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // 2. Tiêu đề
              const Text(
                'Tạo tài khoản',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 32),

              // 3. Ô Email
              _buildInputField(
                label: 'Email',
                hintText: 'name@example.com',
                prefixIcon: Icons.mail_outline,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),

              // 4. Ô Tên đăng nhập (Username)
              _buildInputField(
                label: 'Tên đăng nhập',
                hintText: 'sakura99',
                prefixIcon: Icons.account_circle_outlined,
                controller: _usernameController,
              ),
              const SizedBox(height: 18),

              // 5. Ô Họ và tên (DisplayName)
              _buildInputField(
                label: 'Họ và tên',
                hintText: 'Nguyễn Văn A',
                prefixIcon: Icons.person_outline,
                controller: _nameController,
              ),
              const SizedBox(height: 18),

              // 6. Ô Mật khẩu
              _buildInputField(
                label: 'Mật khẩu',
                hintText: 'Tối thiểu 6 ký tự',
                prefixIcon: Icons.lock_outline,
                controller: _passwordController,
                obscureText: _obscurePassword,
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
              ),
              const SizedBox(height: 16),

              // 7. Checkbox Đồng ý điều khoản
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreeTerms,
                      activeColor: const Color(0xFF0D1B3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _agreeTerms = val ?? false;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(text: 'Tôi đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' & '),
                          TextSpan(
                            text: 'Chính sách quyền riêng tư',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' của Kotoba'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 8. Nút Tạo tài khoản
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
                  onPressed: _isLoading ? null : _handleRegister,
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
                              'Tạo tài khoản',
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
              const SizedBox(height: 28),

              // 9. Kẻ ngang phân cách
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
              const SizedBox(height: 20),

              // 10. Nút Google với icon assets
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
                          _showSnackBar('Tính năng đăng ký Google đang phát triển', isError: false);
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
              const SizedBox(height: 28),

              // 11. Chuyển sang màn Đăng nhập
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              }
                            },
                      child: const Text(
                        'Đăng nhập ngay',
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