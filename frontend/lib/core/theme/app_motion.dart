import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Thông số chuyển động dùng chung để mọi chuyển trang / chuyển tab / mở sheet
/// có cùng nhịp. Muốn đổi cảm giác animation của cả app thì sửa ở đây.
class AppMotion {
  AppMotion._();

  /// Chuyển giữa các tab / trang cùng cấp (bottom nav, Following ↔ For You).
  static const Duration page = Duration(milliseconds: 300);
  static const Curve pageCurve = Curves.easeInOutCubic;

  /// Trang bị "kéo ngược" (vd. thử vào tab cần đăng nhập rồi bật về).
  static const Duration quick = Duration(milliseconds: 220);
  static const Curve quickCurve = Curves.easeOutCubic;

  /// Chuyển trang bằng Navigator (push / pop). Cùng một kiểu trượt ngang kèm
  /// vuốt-cạnh-để-quay-lại trên mọi nền tảng, thay vì mỗi nền tảng một kiểu
  /// (Android zoom, iOS trượt, web/desktop fade) như mặc định của Material.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    },
  );
}
