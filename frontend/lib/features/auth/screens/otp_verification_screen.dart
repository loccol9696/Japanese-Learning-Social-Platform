import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_exception.dart';
import '../data/services/auth_service.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showSnackBar('Vui lòng nhập mã OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.verifyOtp(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) return;
      _showSnackBar('Kích hoạt tài khoản thành công! Vui lòng đăng nhập.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Đã xảy ra lỗi khi xác thực OTP. Vui lòng thử lại.', isError: true);
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
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Không thể gửi lại mã OTP. Vui lòng thử lại sau.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
              const SizedBox(height: 32),

              const Text(
                'Xác thực OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                  children: [
                    const TextSpan(text: 'Mã xác thực gồm 6 chữ số đã được gửi tới email:\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1B3E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              const Text(
                'Mã OTP',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    color: Colors.grey.shade300,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
              const SizedBox(height: 28),

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
                  onPressed: _isLoading ? null : _handleVerifyOtp,
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
                              'Xác thực tài khoản',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: 20, color: Colors.white),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Gửi lại mã sau $_resendCountdown giây',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _handleResendOtp,
                        child: _isResending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Gửi lại mã OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D1B3E),
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
