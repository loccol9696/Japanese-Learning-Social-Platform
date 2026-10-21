import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  info,
}

/// Hệ thống thông báo Top Toast dạng bong bóng nổi (Floating Pill) chuẩn TikTok.
///
/// - Xuất hiện ở đỉnh màn hình (phía dưới tab header "Đang theo dõi / Dành cho bạn").
/// - Không đè lên thanh Bottom Navigation Bar.
/// - Không chặn cử chỉ chạm/vuốt của người dùng (IgnorePointer).
/// - Tự động trượt từ trên xuống, hiển thị 2 giây và trượt mờ dần biến mất.
class AppToast {
  AppToast._();

  /// NavigatorKey toàn cục dùng để tìm Overlay khi context không sẵn sàng hoặc
  /// màn hình vừa bị unmount do điều hướng.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _currentEntry;
  static _ToastAnimationHandle? _currentHandle;

  /// Hiển thị thông báo Toast.
  ///
  /// [context] là tùy chọn. Nếu không truyền hoặc widget đã unmount, hệ thống
  /// sẽ dùng [navigatorKey].
  static void show(
    String message, {
    BuildContext? context,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
    IconData? customIcon,
  }) {
    if (message.trim().isEmpty) return;

    // Tìm OverlayState
    OverlayState? overlay;
    if (context != null && context.mounted) {
      overlay = Overlay.maybeOf(context);
    }
    overlay ??= navigatorKey.currentState?.overlay;

    if (overlay == null) {
      debugPrint('[AppToast] Không tìm thấy OverlayState để hiển thị Toast: $message');
      return;
    }

    // Nếu đang có Toast hiển thị, đóng nó trước
    _dismissCurrent();

    late final OverlayEntry entry;
    final handle = _ToastAnimationHandle();
    _currentHandle = handle;

    entry = OverlayEntry(
      builder: (ctx) {
        // Tính toán khoảng cách an toàn từ đỉnh màn hình:
        // Đặt phía dưới thanh tab header (SafeArea.top + 56px của HomeHeader + 10px đệm)
        final topSafeArea = MediaQuery.of(ctx).padding.top;
        final topOffset = topSafeArea + 56.0 + 10.0;

        return Positioned(
          top: topOffset,
          left: 16.0,
          right: 16.0,
          child: IgnorePointer(
            ignoring: true,
            child: Material(
              type: MaterialType.transparency,
              child: Align(
                alignment: Alignment.topCenter,
                child: _ToastBubble(
                  message: message,
                  type: type,
                  customIcon: customIcon,
                  duration: duration,
                  handle: handle,
                  onDismissed: () {
                    if (_currentEntry == entry) {
                      entry.remove();
                      _currentEntry = null;
                      _currentHandle = null;
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Helper hiển thị thông báo thành công (icon check xanh nhẹ, nền đen mờ).
  static void showSuccess(
    String message, {
    BuildContext? context,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      message,
      context: context,
      type: ToastType.success,
      duration: duration,
    );
  }

  /// Helper hiển thị thông báo lỗi (icon lỗi đỏ dịu, nền đen mờ).
  static void showError(
    String message, {
    BuildContext? context,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      message,
      context: context,
      type: ToastType.error,
      duration: duration,
    );
  }

  /// Helper hiển thị thông báo thông tin (icon info xanh lam nhẹ, nền đen mờ).
  static void showInfo(
    String message, {
    BuildContext? context,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      message,
      context: context,
      type: ToastType.info,
      duration: duration,
    );
  }

  static void _dismissCurrent() {
    _currentHandle?.dismiss();
    _currentHandle = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _ToastAnimationHandle {
  VoidCallback? _dismissCallback;

  void register(VoidCallback callback) {
    _dismissCallback = callback;
  }

  void dismiss() {
    _dismissCallback?.call();
    _dismissCallback = null;
  }
}

class _ToastBubble extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? customIcon;
  final Duration duration;
  final _ToastAnimationHandle handle;
  final VoidCallback onDismissed;

  const _ToastBubble({
    required this.message,
    required this.type,
    this.customIcon,
    required this.duration,
    required this.handle,
    required this.onDismissed,
  });

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    // Hiệu ứng trượt nhẹ từ trên xuống (Offset(0, -0.5) -> Offset.zero)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Hiệu ứng mờ dần (0.0 -> 1.0)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    widget.handle.register(_manualDismiss);

    _controller.forward().then((_) {
      if (!mounted) return;
      _dismissTimer = Timer(widget.duration, () {
        if (mounted && !_isExiting) {
          _exit();
        }
      });
    });
  }

  void _manualDismiss() {
    _dismissTimer?.cancel();
    if (!mounted || _isExiting) return;
    _exit();
  }

  void _exit() {
    _isExiting = true;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color iconColor) = switch (widget.type) {
      ToastType.success => (
          widget.customIcon ?? Icons.check_circle_rounded,
          const Color(0xFF4ADE80), // Xanh lá sáng nhẹ TikTok style
        ),
      ToastType.error => (
          widget.customIcon ?? Icons.error_outline_rounded,
          const Color(0xFFF87171), // Đỏ cam nhẹ nhàng
        ),
      ToastType.info => (
          widget.customIcon ?? Icons.info_outline_rounded,
          const Color(0xFF60A5FA), // Xanh dương nhẹ
        ),
    };

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 9.5,
              ),
              decoration: BoxDecoration(
                // Nền đen mờ 88% hòa hợp Dark Mode, không dùng khối màu xanh đặc
                color: const Color(0xE0171717),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.75,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 18.0,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 19.0,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8.5),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
