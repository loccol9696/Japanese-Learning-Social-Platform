import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Nút "+" vuông bo góc màu nhấn, đặt bên phải ô tìm kiếm ở các màn danh sách (Thư viện thẻ, Tin nhắn).
class SquareAddButton extends StatelessWidget {
  const SquareAddButton({super.key, required this.onPressed, required this.tooltip});

  /// Cạnh của nút; cao bằng ô tìm kiếm bên cạnh.
  static const double size = 50;

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.accent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.add_rounded, color: AppPalette.onAccent, size: 26),
          ),
        ),
      ),
    );
  }
}
