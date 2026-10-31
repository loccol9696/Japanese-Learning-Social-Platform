import 'package:flutter/material.dart';

import '../data/models/auth_response_model.dart';
import '../password_policy.dart';
import '../widgets/google_sign_in_button.dart';
import '../../../app/routes.dart';

import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/services/auth_service.dart';
import 'auth_layout.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import '../../../core/theme/app_palette.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Khớp với ràng buộc backend (RegisterRequest).
  static const int _usernameMin = 3;
  static const int _usernameMax = 50;
  static const int _passwordMax = 72; // BCrypt chỉ dùng 72 byte đầu
  static const int _emailMax = 254;

  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );
  static final RegExp _whitespace = RegExp(r'\s');

  /// Họ và tên: chỉ chữ cái, các từ cách nhau đúng một khoảng trắng (khớp DisplayNameRules ở server).
  static final RegExp _displayNameRegex = RegExp(
    r'^[\p{L}\p{M}]+( [\p{L}\p{M}]+)*$',
    unicode: true,
  );
  static const int _displayNameMax = 100;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập Email';
    if (email.length > _emailMax || !_emailRegex.hasMatch(email)) {
      return 'Định dạng email không hợp lệ';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Vui lòng nhập Họ và tên';
    if (name.length > _displayNameMax) {
      return 'Họ và tên tối đa $_displayNameMax ký tự';
    }
    if (!_displayNameRegex.hasMatch(name)) {
      return 'Họ và tên chỉ gồm chữ cái và khoảng trắng, không có ký tự đặc biệt';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Vui lòng nhập Tên đăng nhập';
    if (username.length < _usernameMin || username.length > _usernameMax) {
      return 'Tên đăng nhập phải từ $_usernameMin đến $_usernameMax ký tự';
    }
    if (_whitespace.hasMatch(username)) {
      return 'Tên đăng nhập không được chứa khoảng trắng';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập Mật khẩu';
    if (password.trim() != password) {
      return 'Mật khẩu không được bắt đầu hoặc kết thúc bằng khoảng trắng';
    }
    return validateNewPassword(password);
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.register(
        username: username,
        email: email,
        password: password,
        displayName: _displayNameController.text.trim(),
      );

      if (!mounted) return;

      _showSnackBar(
        'Đăng ký thành công! Vui lòng kiểm tra mã OTP trong email.',
      );

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
    if (isError) {
      AppToast.showError(message, context: context);
    } else {
      AppToast.showSuccess(message, context: context);
    }
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    OutlineInputBorder border([Color? color, double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppPalette.textPrimary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ...?inputFormatters,
          ],
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onFieldSubmitted,
          enabled: !_isLoading,
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppPalette.accent,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: AppPalette.textSecondary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(AppPalette.accent),
            errorBorder: border(AppPalette.error, 1),
            focusedErrorBorder: border(AppPalette.error),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }

  void _onGoogleSuccess(AuthResponseModel response) {
    if (!mounted) return;
    final name = response.user?.displayName ?? response.user?.username ?? 'bạn';
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    AppToast.showSuccess('Đăng nhập thành công! Chào mừng $name');
  }

  void _onGoogleError(String message) {
    if (mounted) _showSnackBar(message, isError: true);
  }

  void _goToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: authPagePadding(context),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: AppPalette.textPrimary,
                          ),
                          onPressed: _goToLogin,
                        ),
                        const SizedBox(height: 32),

                        Text(
                          'Tạo tài khoản',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildInputField(
                          label: 'Email',
                          hintText: 'name@example.com',
                          prefixIcon: Icons.mail_outline,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          maxLength: _emailMax,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(_whitespace),
                          ],
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 18),

                        _buildInputField(
                          label: 'Họ và tên',
                          hintText: 'Nguyễn Văn An',
                          prefixIcon: Icons.badge_outlined,
                          controller: _displayNameController,
                          validator: _validateDisplayName,
                          maxLength: _displayNameMax,
                          // Chặn ngay lúc gõ: chỉ nhận chữ cái và khoảng trắng.
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\p{L}\p{M} ]', unicode: true),
                            ),
                          ],
                          autofillHints: const [AutofillHints.name],
                        ),
                        const SizedBox(height: 18),

                        _buildInputField(
                          label: 'Tên đăng nhập',
                          hintText: 'sakura99',
                          prefixIcon: Icons.person_outline,
                          controller: _usernameController,
                          validator: _validateUsername,
                          maxLength: _usernameMax,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(_whitespace),
                          ],
                          autofillHints: const [AutofillHints.newUsername],
                        ),
                        const SizedBox(height: 18),

                        _buildInputField(
                          label: 'Mật khẩu',
                          hintText: 'Tối thiểu 8 ký tự, gồm chữ và số',
                          prefixIcon: Icons.lock_outline,
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          maxLength: _passwordMax,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _handleRegister();
                          },
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
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleRegister,
                            child: _isLoading
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppPalette.textPrimary,
                                    ),
                                  )
                                : Text(
                                    'Tạo tài khoản',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppPalette.textPrimary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppPalette.border,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'hoặc',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.textSecondary,
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
                        const SizedBox(height: 20),

                        GoogleSignInButton(
                          enabled: !_isLoading,
                          onSuccess: _onGoogleSuccess,
                          onError: _onGoogleError,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Dòng chuyển sang Đăng nhập cố định ở đáy màn hình.
            Padding(
              padding: EdgeInsets.fromLTRB(
                authPagePadding(context).left,
                8,
                authPagePadding(context).right,
                24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đã có tài khoản? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : _goToLogin,
                    child: Text(
                      'Đăng nhập',
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
          ],
        ),
      ),
    );
  }
}
