import 'package:flutter/material.dart';

import 'theme_manager.dart';
import 'theme_palette.dart';

/// Lối vào màu của toàn app: mỗi getter trả về màu của bộ màu ĐANG CHỌN
/// (tối / sáng) trong [ThemeManager]. Đổi theme là đổi tất cả — không hardcode
/// màu ở nơi khác. Xem quy tắc đầy đủ ở [ThemePalette].
///
/// Các getter không phải hằng số nên không dùng được trong biểu thức `const`.
class AppPalette {
  AppPalette._();

  static ThemePalette get current => ThemeManager.instance.palette;

  /// Nền chính (Scaffold).
  static Color get background => current.background;

  /// Nền thành phần: thẻ, container, thanh tìm kiếm, bảng (bottom sheet).
  static Color get surface => current.surface;

  /// Điều khiển nhỏ trên nền chính / trên thẻ: ô nhập liệu, chip chưa chọn,
  /// rãnh công tắc.
  static Color get surfaceHigh => current.surfaceHigh;

  /// Tầng nổi cao nhất (thẻ lồng trong thẻ, trạng thái nhấn).
  static Color get surfaceHighest => current.surfaceHighest;

  /// Màu nhấn: nút chính, mục đang chọn, con trỏ nhập liệu.
  static Color get accent => current.accent;

  /// Chữ / icon trên nền [accent].
  static Color get onAccent => current.onAccent;

  /// Chữ chính, tiêu đề, icon đang chọn.
  static Color get textPrimary => current.textPrimary;

  /// Chữ phụ, placeholder, mô tả nhỏ, icon mặc định.
  static Color get textSecondary => current.textSecondary;

  /// Tên gọi khác của [surface] cho các bảng / thanh nổi trên nền chính.
  static Color get navBar => current.surface;

  /// Viền / đường kẻ mảnh.
  static Color get border => current.border;

  /// Nền nhấn nhẹ (badge, vùng chọn).
  static Color get accentSoft => current.accentSoft;

  /// Lớp phủ mờ phía sau dialog / bottom sheet.
  static Color get scrim => current.scrim;

  /// Màu đổ bóng.
  static Color get shadow => current.shadow;

  // ---- Màu ngữ nghĩa ----
  static Color get success => current.success;
  static Color get successContainer => current.successContainer;
  static Color get warning => current.warning;
  static Color get warningContainer => current.warningContainer;
  static Color get error => current.error;
  static Color get errorContainer => current.errorContainer;
  static Color get info => current.info;
  static Color get infoContainer => current.infoContainer;
  static Color get gold => current.gold;
  static Color get like => current.like;

  // ---- Trên video (luôn tối / sáng cố định ở cả hai chế độ) ----
  static Color get videoScrim => current.videoScrim;
  static Color get onVideo => current.onVideo;
  static Color get onVideoMuted => current.onVideoMuted;
}
