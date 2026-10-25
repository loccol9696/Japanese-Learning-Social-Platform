import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/auth_session.dart';
import 'auth_layout.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';
import '../../../core/theme/app_palette.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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

  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );
  static final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9._]+$');

  String? _validateIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'Vui lòng nhập Email hoặc Tên đăng nhập';

    if (identifier.contains('@')) {
      if (!_emailRegex.hasMatch(identifier)) {
        return 'Định dạng email không hợp lệ';
      }
    } else if (identifier.length > 50 ||
        !_usernameRegex.hasMatch(identifier) ||
        identifier.startsWith('.') ||
        identifier.endsWith('.') ||
        identifier.contains('..')) {
      return 'Tên đăng nhập không hợp lệ';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập Mật khẩu';
    if (value.length > 72) return 'Mật khẩu tối đa 72 ký tự';
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final rawIdentifier = _emailController.text.trim();
    final identifier = rawIdentifier.contains('@')
        ? rawIdentifier.toLowerCase()
        : rawIdentifier;
    final password = _passwordController.text;
    setState(() => _isLoading = true);

    try {
      final response = await AuthSession.instance.login(
        email: identifier,
        password: password,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      final displayName =
          response.user?.displayName ?? response.user?.username ?? 'bạn';

      // Clear any pending snackbars before navigation
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

      // Navigate to Home screen
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

      AppToast.showSuccess('Đăng nhập thành công! Chào mừng $displayName');
    } on ApiException catch (e) {
      if (!mounted) return;

      // 403 = mật khẩu đúng nhưng tài khoản chưa kích hoạt: hướng dẫn xác thực OTP.
      // (Sai email/mật khẩu là 401, bị khoá tạm vì sai nhiều lần là 429.)
      if (e.statusCode == 403) {
        _showInactiveDialog(identifier);
      } else {
        _showSnackBar(e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'Đã xảy ra lỗi đăng nhập. Vui lòng thử lại.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInactiveDialog(String emailOrUsername) {
    // Backend chỉ xác thực OTP theo email. Nếu người dùng đăng nhập bằng
    // username thì cần hỏi lại email.
    final emailController = TextEditingController(
      text: emailOrUsername.contains('@') ? emailOrUsername : '',
    );
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppPalette.warning, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tài khoản chưa kích hoạt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tài khoản của bạn chưa được kích hoạt. Chúng tôi sẽ gửi mã OTP mới tới email đăng ký của bạn.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: emailController.text.isEmpty,
                decoration: InputDecoration(
                  labelText: 'Email đăng ký',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Đóng', style: TextStyle(color: AppPalette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final email = emailController.text.trim().toLowerCase();
                if (!emailRegex.hasMatch(email)) {
                  setDialogState(() => errorText = 'Email không hợp lệ');
                  return;
                }
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OtpVerificationScreen(
                      email: email,
                      sendCodeOnOpen: true,
                    ),
                  ),
                );
              },
              child: Text(
                'Gửi mã OTP',
                style: TextStyle(color: AppPalette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(emailController.dispose);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      AppToast.showError(message, context: context);
    } else {
      AppToast.showSuccess(message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: authPagePadding(context),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nút quay lại (ẩn khi Login là màn hình gốc)
                  if (Navigator.of(context).canPop())
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(height: 32),

                  // 2. Tiêu đề Đăng nhập
                  Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3. Nhãn Email
                  Text(
                    'Email/Tên đăng nhập',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ô nhập Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                    validator: _validateIdentifier,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    autofillHints: const [AutofillHints.email],
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppPalette.accent,
                    decoration: InputDecoration(
                      hintText: 'name@gmail.com',
                      hintStyle: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        size: 20,
                        color: AppPalette.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppPalette.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppPalette.accent,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppPalette.error,
                          width: 1.5,
                        ),
                      ),
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Nhãn Mật khẩu
                  Text(
                    'Mật khẩu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ô nhập Mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autofillHints: const [AutofillHints.password],
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppPalette.accent,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _handleLogin();
                    },
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu',
                      hintStyle: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: AppPalette.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppPalette.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppPalette.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppPalette.accent,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppPalette.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppPalette.error,
                          width: 1.5,
                        ),
                      ),
                      errorMaxLines: 2,
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
                              activeColor: AppPalette.accent,
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
                          Text(
                            'Ghi nhớ đăng nhập',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ForgotPasswordScreen(
                                      initialEmail: _emailController.text
                                          .trim(),
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.textPrimary,
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
                        backgroundColor: AppPalette.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppPalette.textPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.textPrimary,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: AppPalette.textPrimary,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 7. Dòng kẻ "HOẶC TIẾP TỤC VỚI"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppPalette.border,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC TIẾP TỤC VỚI',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppPalette.border,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 8. Nút đăng nhập Google
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppPalette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              _showSnackBar(
                                'Tính năng đăng nhập Google đang phát triển',
                                isError: false,
                              );
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/google.png',
                            height: 20,
                            width: 20,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: AppPalette.error,
                                ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.textPrimary,
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
                        Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(fontSize: 14, color: AppPalette.textSecondary),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.textPrimary,
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
        ),
      ),
    );
  }
}
