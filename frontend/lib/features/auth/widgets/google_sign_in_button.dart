import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../data/auth_session.dart';
import '../data/google_auth_service.dart';
import '../data/models/auth_response_model.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

/// Nút "Tiếp tục với Google" dùng chung cho màn Đăng nhập và Đăng ký.
///
/// Web: nút do Google vẽ, token đến qua luồng sự kiện. Android / iOS: nút riêng mở hộp chọn tài khoản.
class GoogleSignInButton extends StatefulWidget {
  final bool enabled;
  final ValueChanged<AuthResponseModel> onSuccess;
  final ValueChanged<String> onError;

  const GoogleSignInButton({
    super.key,
    required this.onSuccess,
    required this.onError,
    this.enabled = true,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  static const String _unavailable =
      'Đăng nhập bằng Google chưa khả dụng trên thiết bị này.';

  StreamSubscription<String>? _webSubscription;
  bool _ready = false;
  bool _usesNativeFlow = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _webSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await GoogleAuthService.instance.ensureInitialized();
      final native = GoogleAuthService.instance.supportsNativeFlow;
      if (!native) {
        _webSubscription = GoogleAuthService.instance.webIdTokens.listen(
          _complete,
          onError: _handleError,
        );
      }
      if (!mounted) return;
      setState(() {
        _usesNativeFlow = native;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = false);
    }
  }

  Future<void> _startNative() async {
    if (_busy || !widget.enabled) return;
    if (!_ready) {
      widget.onError(_unavailable);
      return;
    }
    setState(() => _busy = true);
    try {
      final idToken = await GoogleAuthService.instance.authenticateNative();
      if (idToken == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _complete(idToken);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _complete(String idToken) async {
    // Hai màn Đăng nhập / Đăng ký có thể cùng tồn tại: chỉ màn đang hiển thị xử lý.
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) return;
    if (!_busy) setState(() => _busy = true);
    try {
      final response = await AuthSession.instance.loginWithGoogle(idToken);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSuccess(response);
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object error) {
    if (!mounted) return;
    setState(() => _busy = false);
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      widget.onError('Không đăng nhập được bằng Google (${error.code.name}).');
    } else if (error is ApiException) {
      widget.onError(error.message);
    } else {
      widget.onError('Không đăng nhập được bằng Google. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && !_usesNativeFlow) {
      return SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              ignoring: !widget.enabled || _busy,
              child: Opacity(
                opacity: widget.enabled && !_busy ? 1 : 0.5,
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: buildWebGoogleButton(constraints.maxWidth),
                  ),
                ),
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppPalette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: widget.enabled && !_busy ? _startNative : null,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/google.png',
                    height: 20,
                    width: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tiếp tục với Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
