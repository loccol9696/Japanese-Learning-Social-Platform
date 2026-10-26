import 'package:flutter/material.dart';

/// Bộ màu của MỘT chế độ giao diện (tối hoặc sáng).
///
/// QUY TẮC MÀU (bắt buộc cho mọi UI mới):
/// 1. Không viết `Color(0x...)`, `Colors.white`, `Colors.black` trong màn hình /
///    widget. Mọi màu phải lấy từ [AppColors] / [AppPalette] (các getter đọc từ
///    bộ màu đang chọn) hoặc `Theme.of(context)`.
/// 2. Muốn thêm màu mới → thêm 1 trường vào [ThemePalette] và điền giá trị cho
///    CẢ [ThemePalette.dark] lẫn [ThemePalette.light]. Đổi theme là đổi tất cả.
/// 3. Nền theo tầng: [background] (nền trang) < [surface] (thẻ, sheet, thanh
///    điều hướng) < [surfaceHigh] (ô nhập, chip chưa chọn, rãnh công tắc).
///    Tông nền là ĐEN XÁM trung tính (không ngả xanh/tím).
/// 4. Màu ngữ nghĩa (thành công, cảnh báo, lỗi, thông tin, vàng) luôn đi kèm
///    một biến `*Container` làm nền nhạt của chính nó.
/// 5. Lớp phủ trên video (scrim) luôn tối ở cả hai chế độ vì nền là video.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accentSoft,
    required this.scrim,
    required this.shadow,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.gold,
    required this.like,
    required this.videoScrim,
    required this.onVideo,
    required this.onVideoMuted,
  });

  final Brightness brightness;

  /// Nền chính (Scaffold).
  final Color background;

  /// Nền thành phần: thẻ, container, thanh tìm kiếm, bảng (bottom sheet).
  final Color surface;

  /// Điều khiển nhỏ nằm trên nền chính hoặc trên thẻ: ô nhập liệu, chip chưa
  /// chọn, rãnh công tắc.
  final Color surfaceHigh;

  /// Tầng nổi cao nhất: thẻ lồng trong thẻ, phần tử đang hover / nhấn.
  final Color surfaceHighest;

  /// Màu nhấn: nút chính, mục đang chọn, con trỏ nhập liệu.
  final Color accent;

  /// Chữ / icon nằm trên nền [accent] (và trên các nút màu đặc).
  final Color onAccent;

  /// Chữ chính, tiêu đề, icon đang chọn.
  final Color textPrimary;

  /// Chữ phụ, placeholder, mô tả nhỏ, icon mặc định.
  final Color textSecondary;

  /// Viền / đường kẻ mảnh.
  final Color border;

  /// Nền nhấn nhẹ: nền badge, vùng chọn.
  final Color accentSoft;

  /// Lớp phủ mờ phía sau dialog / bottom sheet.
  final Color scrim;

  /// Màu đổ bóng.
  final Color shadow;

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;

  /// Vàng (sao, streak, Premium, đánh dấu lưu).
  final Color gold;

  /// Đỏ hồng của nút tim / thích.
  final Color like;

  /// Màu gốc của lớp phủ gradient trên video; luôn tối.
  final Color videoScrim;

  /// Chữ / icon nằm trên video hoặc trên [videoScrim]; luôn sáng.
  final Color onVideo;

  /// Chữ phụ nằm trên video.
  final Color onVideoMuted;

  bool get isDark => brightness == Brightness.dark;

  /// Xanh navy đậm: các tầng sáng dần theo độ nổi.
  static const ThemePalette dark = ThemePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0A092D),
    surface: Color(0xFF1A1D42),
    surfaceHigh: Color(0xFF2E3856),
    surfaceHighest: Color(0xFF3A4668),
    accent: Color(0xFF4255FF),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF939BB4),
    border: Color(0x40939BB4),
    accentSoft: Color(0x2E4255FF),
    scrim: Color(0xB3000000),
    shadow: Color(0x66000000),
    success: Color(0xFF34D399),
    successContainer: Color(0xFF12281F),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFF2B2210),
    error: Color(0xFFF87171),
    errorContainer: Color(0xFF2E1719),
    info: Color(0xFF38BDF8),
    infoContainer: Color(0xFF10232E),
    gold: Color(0xFFFFD700),
    like: Color(0xFFFE2C55),
    videoScrim: Color(0xFF0A092D),
    onVideo: Color(0xFFFFFFFF),
    onVideoMuted: Color(0xB3FFFFFF),
  );

  /// Sáng: nền xám nhạt, thẻ trắng, chữ đen xám.
  static const ThemePalette light = ThemePalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F2F4),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE8E8EC),
    surfaceHighest: Color(0xFFDADADF),
    accent: Color(0xFF3346F0),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF6B6B75),
    border: Color(0x336B6B75),
    accentSoft: Color(0x1F3346F0),
    scrim: Color(0x80000000),
    shadow: Color(0x1A000000),
    success: Color(0xFF059669),
    successContainer: Color(0xFFD9F5E8),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFDEFD2),
    error: Color(0xFFDC2626),
    errorContainer: Color(0xFFFCE0E0),
    info: Color(0xFF0284C7),
    infoContainer: Color(0xFFDCF0FB),
    gold: Color(0xFFD99A00),
    like: Color(0xFFE11D48),
    videoScrim: Color(0xFF0A092D),
    onVideo: Color(0xFFFFFFFF),
    onVideoMuted: Color(0xB3FFFFFF),
  );
}
