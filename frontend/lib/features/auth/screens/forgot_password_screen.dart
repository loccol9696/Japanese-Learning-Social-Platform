import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/services/auth_service.dart';
import 'auth_layout.dart';

/// Quên mật khẩu, 2 bước:
/// 1. Nhập email -> server gửi mã OTP (luôn báo cùng một thông điệp để không
///    lộ email nào đã đăng ký).
/// 2. Nhập mã OTP + mật khẩu mới -> đặt lại, quay về màn Đăng nhập.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _primary = Color(0xFF0D1B3E);
  static const int _otpLength = 6;
  static const int _passwordMin = 6;
  static const int _passwordMax = 72;
  static const int _resendCooldownSeconds = 60;

  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = _resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
        return;
      }
      setState(() => _resendCountdown--);
    });
  }

  Future<void> _sendCode() async {
    if (_isLoading) return;
    if (!_codeSent && !(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.forgotPassword(email: _email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCountdown();
      _showSnackBar(
        'Nếu email đã đăng ký, mã đặt lại mật khẩu đã được gửi. '
        'Vui lòng kiểm tra hộp thư (cả mục Spam).',
      );
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Không gửi được mã. Vui lòng thử lại.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.resetPassword(
        email: _email,
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _showSnackBar('Đặt lại mật khẩu thành công! Vui lòng đăng nhập.');
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _otpController.clear();
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Không đặt lại được mật khẩu. Vui lòng thử lại.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRegex.hasMatch(email)) return 'Định dạng email không hợp lệ';
    return null;
  }

  String? _validateOtp(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.isEmpty) return 'Vui lòng nhập mã OTP';
    if (otp.length != _otpLength) return 'Mã OTP gồm $_otpLength chữ số';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu mới';
    if (password.length < _passwordMin) {
      return 'Mật khẩu phải có ít nhất $_passwordMin ký tự';
    }
    if (password.trim() != password) {
      return 'Mật khẩu không được bắt đầu hoặc kết thúc bằng khoảng trắng';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    if (value != _passwordController.text) return 'Mật khẩu nhập lại không khớp';
    return null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      AppToast.showError(message, context: context);
    } else {
      AppToast.showSuccess(message, context: context);
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      suffixIcon: suffix,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border(Colors.grey.shade200),
      enabledBorder: border(Colors.grey.shade200),
      focusedBorder: border(_primary, 1.5),
      errorBorder: border(const Color(0xFFE53935)),
      focusedErrorBorder: border(const Color(0xFFE53935), 1.5),
      errorMaxLines: 2,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      );

  Widget _primaryButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: authPagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black87),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Quên mật khẩu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Nhập mã gồm 6 chữ số đã gửi tới $_email và mật khẩu mới.'
                        : 'Nhập email đã đăng ký, chúng tôi sẽ gửi mã để đặt lại mật khẩu.',
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  _codeSent ? _buildResetForm() : _buildEmailForm(),
                  const SizedBox(height: 36),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Nhớ mật khẩu? ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Đăng nhập ngay',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Email'),
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            validator: _validateEmail,
            onFieldSubmitted: (_) => _sendCode(),
            style: const TextStyle(color: _primary, fontSize: 15, fontWeight: FontWeight.w500),
            cursorColor: _primary,
            decoration: _decoration(hint: 'name@gmail.com', icon: Icons.mail_outline),
          ),
          const SizedBox(height: 32),
          _primaryButton(label: 'Gửi mã xác nhận', onPressed: _sendCode),
        ],
      ),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Mã OTP'),
          TextFormField(
            controller: _otpController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: _otpLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validateOtp,
            style: const TextStyle(
              color: _primary,
              fontSize: 18,
              letterSpacing: 6,
              fontWeight: FontWeight.bold,
            ),
            cursorColor: _primary,
            decoration: _decoration(hint: '6 chữ số', icon: Icons.pin_outlined),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading || _resendCountdown > 0 ? null : _sendCode,
              child: Text(
                _resendCountdown > 0 ? 'Gửi lại mã sau $_resendCountdown giây' : 'Gửi lại mã',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          _label('Mật khẩu mới'),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            maxLength: _passwordMax,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validatePassword,
            onChanged: (_) {
              if (_confirmController.text.isNotEmpty) {
                _confirmFieldKey.currentState?.validate();
              }
            },
            style: const TextStyle(color: _primary, fontSize: 15, fontWeight: FontWeight.w500),
            cursorColor: _primary,
            decoration: _decoration(
              hint: 'Tối thiểu 6 ký tự',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _label('Nhập lại mật khẩu mới'),
          TextFormField(
            key: _confirmFieldKey,
            controller: _confirmController,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            maxLength: _passwordMax,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validateConfirm,
            onFieldSubmitted: (_) => _resetPassword(),
            style: const TextStyle(color: _primary, fontSize: 15, fontWeight: FontWeight.w500),
            cursorColor: _primary,
            decoration: _decoration(hint: 'Nhập lại mật khẩu ở trên', icon: Icons.lock_outline),
          ),
          const SizedBox(height: 28),
          _primaryButton(label: 'Đặt lại mật khẩu', onPressed: _resetPassword),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _otpController.clear();
                    }),
            child: const Text('Đổi email khác'),
          ),
        ],
      ),
    );
  }
}
