import 'package:flutter/painting.dart';

/// Hệ màu chính của toàn bộ app (nền tối).
///
/// Chỉ có 5 màu gốc; các màu còn lại (viền, lớp phủ) đều được suy ra từ chúng.
class AppPalette {
  AppPalette._();

  /// Nền chính (Scaffold).
  static const Color background = Color(0xFF0A092D);

  /// Nền thành phần: thẻ, container, thanh tìm kiếm, bảng (bottom sheet).
  /// Đo từ màn Thư viện thẻ — màn chuẩn để đồng bộ giao diện toàn app.
  static const Color surface = Color(0xFF1A1D42);

  /// Nền cho điều khiển nhỏ nằm trên nền chính hoặc trên thẻ để nổi bật hơn:
  /// ô nhập liệu, chip chưa chọn, rãnh công tắc.
  static const Color surfaceHigh = Color(0xFF2E3856);

  /// Màu nhấn nổi bật: nút +, nút chính, mục đang chọn, con trỏ nhập liệu.
  static const Color accent = Color(0xFF4255FF);

  /// Chữ chính, tiêu đề, icon đang chọn.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Chữ phụ, placeholder, mô tả nhỏ, icon mặc định.
  static const Color textSecondary = Color(0xFF939BB4);

  /// Tên gọi khác của [surface] cho các bảng / thanh nổi lên trên nền chính.
  static const Color navBar = surface;

  // ---- Suy ra từ 5 màu gốc ----

  /// Viền / đường kẻ mảnh: [textSecondary] ở độ đậm 25%.
  static const Color border = Color(0x40939BB4);

  /// Nền nhấn nhẹ: [accent] ở độ đậm 18% (nền badge, vùng chọn).
  static const Color accentSoft = Color(0x2E4255FF);
}
