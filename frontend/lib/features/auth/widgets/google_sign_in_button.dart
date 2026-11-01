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
  String? _initError;

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
    } catch (e) {
      debugPrint('[GOOGLE] khởi tạo lỗi: $e');
      if (!mounted) return;
      setState(() {
        _ready = false;
        _initError = e.toString();
      });
    }
  }

  Future<void> _startNative() async {
    if (_busy || !widget.enabled) return;
    if (!_ready) {
      // Thử khởi tạo lại (vd. vừa mất mạng); nếu vẫn lỗi thì báo kèm nguyên nhân.
      await _initialize();
      if (!_ready) {
        final reason = (_initError ?? '').split('\n').first;
        widget.onError(
          reason.isEmpty ? _unavailable : '$_unavailable ($reason)',
        );
        return;
      }
      if (!_usesNativeFlow) {
        // Web: người dùng cần bấm nút của Google vừa hiện ra.
        return;
      }
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
      // Google không cho đổi giao diện nút trên web, nên đặt nút thật của Google xuống dưới (kéo giãn cho phủ kín
      // khung 52px, rộng bằng nút Đăng nhập) rồi vẽ nút giống thiết kế, đặc hoàn toàn, đè lên trên. Lớp vẽ không
      // nhận chạm nên bấm xuyên xuống nút thật của Google; đang bận hoặc bị khoá thì chặn chạm vào nút thật.
      return SizedBox(
        height: 52,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IgnorePointer(
                  ignoring: !widget.enabled || _busy,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth.clamp(200.0, 400.0);
                      return Center(
                        child: Transform.scale(
                          scaleX: constraints.maxWidth / width,
                          scaleY: 52 / 40,
                          child: SizedBox(
                            width: width,
                            height: 40,
                            child: buildWebGoogleButton(width),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: _buildContent(busy: _busy)),
                ),
              ),
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
          backgroundColor: AppPalette.surface,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: widget.enabled && !_busy ? _startNative : null,
        child: _buildContent(busy: _busy),
      ),
    );
  }

  Widget _buildContent({required bool busy}) {
    return busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Tiếp tục với Google',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.textPrimary,
                ),
              ),
            ],
          );
  }
}
