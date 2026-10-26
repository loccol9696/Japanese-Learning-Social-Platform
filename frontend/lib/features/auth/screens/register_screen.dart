import 'package:flutter/material.dart';
import '../data/models/auth_response_model.dart';
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _confirmFieldKey =
      GlobalKey<FormFieldState<String>>();

  // Khớp với ràng buộc backend (RegisterRequest) và cột display_name (100).
  static const int _usernameMin = 3;
  static const int _usernameMax = 50;
  static const int _displayNameMax = 100;
  static const int _passwordMin = 6;
  static const int _passwordMax = 72; // BCrypt chỉ dùng 72 byte đầu
  static const int _emailMax = 254;

  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );
  static final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9._]+$');
  static final RegExp _whitespace = RegExp(r'\s');

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Vui lòng nhập Tên đăng nhập';
    if (username.length < _usernameMin || username.length > _usernameMax) {
      return 'Tên đăng nhập phải từ $_usernameMin đến $_usernameMax ký tự';
    }
    if (!_usernameRegex.hasMatch(username)) {
      return 'Chỉ dùng chữ cái không dấu, số, dấu chấm (.) hoặc gạch dưới (_)';
    }
    if (username.startsWith('.') ||
        username.endsWith('.') ||
        username.contains('..')) {
      return 'Dấu chấm không được ở đầu, cuối hoặc đứng liền nhau';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Vui lòng nhập Họ và tên hiển thị';
    if (name.length > _displayNameMax) {
      return 'Họ và tên tối đa $_displayNameMax ký tự';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập Mật khẩu';
    if (password.length < _passwordMin) {
      return 'Mật khẩu phải có ít nhất $_passwordMin ký tự';
    }
    if (password.length > _passwordMax) {
      return 'Mật khẩu tối đa $_passwordMax ký tự';
    }
    if (password.trim() != password) {
      return 'Mật khẩu không được bắt đầu hoặc kết thúc bằng khoảng trắng';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại Mật khẩu';
    if (value != _passwordController.text) {
      return 'Mật khẩu nhập lại không khớp';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final displayName = _nameController.text.trim();
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
        displayName: displayName,
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
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
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
          onChanged: onChanged,
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
            prefixIcon: Icon(prefixIcon, size: 20, color: AppPalette.textSecondary),
            suffixIcon: suffixIcon,
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
      ],
    );
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
                  const SizedBox(height: 8),

                  // Tiêu đề
                  Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textPrimary,
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
                    validator: _validateEmail,
                    maxLength: _emailMax,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(_whitespace),
                    ],
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 18),

                  // 4. Ô Tên đăng nhập (Username)
                  _buildInputField(
                    label: 'Tên đăng nhập',
                    hintText: 'sakura99',
                    prefixIcon: Icons.account_circle_outlined,
                    controller: _usernameController,
                    validator: _validateUsername,
                    maxLength: _usernameMax,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(_whitespace),
                    ],
                    autofillHints: const [AutofillHints.newUsername],
                  ),
                  const SizedBox(height: 18),

                  // 5. Ô Họ và tên (DisplayName)
                  _buildInputField(
                    label: 'Họ và tên',
                    hintText: 'Nguyễn Văn A',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    validator: _validateDisplayName,
                    maxLength: _displayNameMax,
                    autofillHints: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 18),

                  // 6. Ô Mật khẩu
                  _buildInputField(
                    label: 'Mật khẩu',
                    hintText: 'Tối thiểu 6 ký tự',
                    prefixIcon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    maxLength: _passwordMax,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) {
                      // Kiểm tra lại ô xác nhận khi mật khẩu thay đổi
                      if (_confirmPasswordController.text.isNotEmpty) {
                        _confirmFieldKey.currentState?.validate();
                      }
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
                  const SizedBox(height: 18),

                  // 6b. Ô Nhập lại mật khẩu
                  _buildInputField(
                    label: 'Nhập lại mật khẩu',
                    hintText: 'Nhập lại mật khẩu ở trên',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmPasswordController,
                    fieldKey: _confirmFieldKey,
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                    maxLength: _passwordMax,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _handleRegister();
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppPalette.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nút Tạo tài khoản
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Tạo tài khoản',
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
                  const SizedBox(height: 28),

                  // 9. Kẻ ngang phân cách
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
                  const SizedBox(height: 20),

                  // Nút "Tiếp tục với Google"
                  GoogleSignInButton(
                    enabled: !_isLoading,
                    onSuccess: _onGoogleSuccess,
                    onError: _onGoogleError,
                  ),
                  const SizedBox(height: 28),

                  // 11. Chuyển sang màn Đăng nhập
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Đã có tài khoản? ',
                          style: TextStyle(fontSize: 14, color: AppPalette.textSecondary),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            'Đăng nhập ngay',
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
