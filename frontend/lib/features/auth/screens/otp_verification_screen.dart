import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/services/auth_service.dart';
import 'auth_layout.dart';
import 'login_screen.dart';
import '../../../core/theme/app_palette.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  /// true khi mở từ màn Đăng nhập (tài khoản chưa kích hoạt): mã cũ có thể
  /// đã hết hạn nên gửi mã mới ngay khi mở màn hình.
  final bool sendCodeOnOpen;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.sendCodeOnOpen = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  static const int _otpLength = 6;
  static const int _resendCooldownSeconds = 60;

  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sendCodeOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleResendOtp());
    } else {
      _startCountdown();
    }
  }

  void _startCountdown() {
    setState(() => _resendCountdown = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (_isLoading) return;
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showSnackBar('Vui lòng nhập mã OTP', isError: true);
      return;
    }
    if (otp.length != _otpLength) {
      _showSnackBar('Mã OTP gồm $_otpLength chữ số', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await AuthService.instance.verifyOtp(email: widget.email, otp: otp);

      if (!mounted) return;
      _showSnackBar('Kích hoạt tài khoản thành công! Vui lòng đăng nhập.');
      _goToLogin();
    } on ApiException catch (e) {
      if (!mounted) return;
      _otpController.clear();
      setState(() {});
      // 409: tài khoản đã kích hoạt từ trước -> chỉ cần đăng nhập.
      if (e.statusCode == 409) {
        _showSnackBar(e.message);
        _goToLogin();
        return;
      }
      // 400: sai mã (kèm số lần thử còn lại); 429: sai quá nhiều lần, cần mã mới.
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'Đã xảy ra lỗi khi xác thực OTP. Vui lòng thử lại.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await AuthService.instance.resendOtp(email: widget.email);
      if (!mounted) return;
      _showSnackBar('Mã OTP mới đã được gửi vào email của bạn.');
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _showSnackBar(e.message);
        _goToLogin();
        return;
      }
      // 404: không có tài khoản; 429: gửi quá nhanh / quá nhiều; 503: mail lỗi.
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'Không thể gửi lại mã OTP. Vui lòng thử lại sau.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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

  bool get _isComplete => _otpController.text.length == _otpLength;

  /// 6 ô số theo thiết kế. Một TextField vô hình phủ lên trên nhận phím và dán mã; các ô chỉ để hiển thị.
  Widget _buildOtpBoxes() {
    final text = _otpController.text;
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < _otpLength; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    key: ValueKey('otp-box-$i'),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: i == text.length && !_isLoading
                            ? AppPalette.accent
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              enableInteractiveSelection: false,
              showCursor: false,
              onChanged: (value) {
                setState(() {});
                // Tự xác thực khi nhập đủ 6 số
                if (value.length == _otpLength) _handleVerifyOtp();
              },
              onSubmitted: (_) => _handleVerifyOtp(),
              maxLength: _otpLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: authPagePadding(context),
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
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 32),

              Text(
                'Xác thực OTP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: AppPalette.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Mã gồm 6 chữ số đã được gửi tới\n'),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildOtpBoxes(),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.accent,
                    disabledBackgroundColor: AppPalette.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading || !_isComplete
                      ? null
                      : _handleVerifyOtp,
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
                          'Xác thực',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isComplete
                                ? AppPalette.textPrimary
                                : AppPalette.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: _resendCountdown > 0 || _isResending
                    ? Text(
                        _isResending
                            ? 'Đang gửi mã...'
                            : 'Gửi lại mã sau $_resendCountdown giây',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textSecondary,
                        ),
                      )
                    : GestureDetector(
                        onTap: _handleResendOtp,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Gửi lại mã',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
