import 'package:flutter/material.dart';

/// Ngọn lửa đặc (không có lỗ bên trong): ngọn nhọn cao ở giữa, một cánh nhỏ bên trái, thân tròn bên dưới.
/// Vẽ bằng đường vẽ vector nên rõ nét ở mọi cỡ và đổi màu theo [color] như một icon.
class FlameIcon extends StatelessWidget {
  const FlameIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: FlamePainter(color)),
    );
  }
}

/// Tỉ lệ chiều rộng / chiều cao của ngọn lửa trong ô vuông của icon.
const double _flameWidthFactor = 0.76;

class FlamePainter extends CustomPainter {
  FlamePainter(this.color);

  final Color color;

  /// Đường viền ngọn lửa; u, v là toạ độ chuẩn hoá 0..1 trong hộp bao của ngọn lửa.
  static Path buildPath(Size size) {
    final s = size.shortestSide;
    final w = s * _flameWidthFactor;
    final dx = (size.width - w) / 2;
    final dy = (size.height - s) / 2;
    Offset p(double u, double v) => Offset(dx + u * w, dy + v * s);

    // Các điểm dưới đây viết theo (u, v) trong hộp bao của ngọn lửa, theo chiều kim đồng hồ từ ngọn.
    final path = Path()..moveTo(p(0.50, 0.00).dx, p(0.50, 0.00).dy);
    void curve(double u1, double v1, double u2, double v2, double u3, double v3) {
      final c1 = p(u1, v1), c2 = p(u2, v2), e = p(u3, v3);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
    }

    // Sườn phải: từ ngọn nhọn phình dần ra thân tròn.
    curve(0.53, 0.10, 0.68, 0.22, 0.82, 0.37);
    curve(0.94, 0.50, 1.00, 0.60, 1.00, 0.72);
    // Đáy tròn.
    curve(1.00, 0.88, 0.80, 1.00, 0.50, 1.00);
    curve(0.20, 1.00, 0.00, 0.88, 0.00, 0.72);
    // Cánh nhỏ bên trái.
    curve(0.00, 0.60, 0.05, 0.50, 0.14, 0.40);
    curve(0.15, 0.48, 0.21, 0.56, 0.30, 0.57);
    // Vết lõm giữa cánh trái và ngọn, rồi lên lại ngọn.
    curve(0.32, 0.42, 0.45, 0.17, 0.50, 0.00);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(buildPath(size), Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) => oldDelegate.color != color;
}
