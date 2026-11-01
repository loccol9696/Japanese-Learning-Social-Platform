import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hiệu ứng lửa lớn bùng lên từ đáy màn hình, chơi một lần mỗi khi [trigger] tăng lên (dùng khi đạt chuỗi đúng
/// liên tiếp). Không chặn cử chỉ chạm.
class FireCelebration extends StatefulWidget {
  const FireCelebration({super.key, required this.trigger});

  /// Tăng giá trị này để chơi hiệu ứng.
  final int trigger;

  /// Tổng thời gian chơi.
  static const Duration duration = Duration(milliseconds: 2000);

  @override
  State<FireCelebration> createState() => _FireCelebrationState();
}

class _FireCelebrationState extends State<FireCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: FireCelebration.duration);

  @override
  void didUpdateWidget(FireCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Chưa chơi hoặc đã chơi xong: gỡ lớp vẽ khỏi cây widget.
          if (_controller.isDismissed || _controller.isCompleted) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              key: const ValueKey('fire-celebration'),
              width: double.infinity,
              height: 260,
              child: CustomPaint(painter: FirePainter(_controller.value)),
            ),
          );
        },
      ),
    );
  }
}

/// Vẽ các ngọn núi lửa chồng nhau: trồi lên từ đáy, lung linh khi giữ, rồi mờ dần và hạ xuống.
class FirePainter extends CustomPainter {
  FirePainter(this.t);

  /// 0..1 theo tiến trình hiệu ứng.
  final double t;

  /// (tâm ngang, độ rộng, độ cao) theo tỉ lệ; thứ tự vẽ từ sau ra trước.
  static const List<(double, double, double)> peaks = [
    (0.60, 0.62, 0.95),
    (0.12, 0.60, 0.52),
    (0.88, 0.58, 0.50),
    (0.36, 0.44, 0.34),
  ];

  static const Color _base = Color(0xFFFF7A00);
  static const Color _tip = Color(0xFFFFC857);

  /// Độ trồi lên (0..1) của cả cụm lửa.
  static double rise(double t) {
    t = t.clamp(0.0, 1.0); // sai số số thực có thể đẩy t vượt 1 một chút, mà Curve.transform không chấp nhận
    if (t < 0.28) return Curves.easeOutBack.transform((t / 0.28).clamp(0.0, 1.0));
    if (t > 0.82) return 1 - Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0)) * 0.35;
    return 1;
  }

  /// Độ đậm (0..1): hiện ra nhanh, mờ dần ở cuối.
  static double opacity(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.12) return t / 0.12;
    if (t > 0.78) return 1 - ((t - 0.78) / 0.22);
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = opacity(t).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final grow = rise(t);

    // Ánh sáng toả phía sau
    final glowCenter = Offset(size.width * 0.6, size.height);
    canvas.drawCircle(
      glowCenter,
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _base.withValues(alpha: 0.45 * alpha),
            _base.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: size.width * 0.55)),
    );

    for (var i = 0; i < peaks.length; i++) {
      final (cx, w, h) = peaks[i];
      // Lung linh: độ cao dao động nhẹ, mỗi ngọn lệch pha.
      final flicker = 1 + 0.06 * math.sin(t * 38 + i * 1.7);
      final peakHeight = size.height * h * grow * flicker;
      final halfWidth = size.width * w / 2;
      final x = size.width * cx;
      final baseY = size.height + 2;
      final topY = baseY - peakHeight;

      // Hai sườn cong nhẹ vào trong để giống ngọn lửa hơn là hình tam giác.
      final path = Path()
        ..moveTo(x - halfWidth, baseY)
        ..quadraticBezierTo(x - halfWidth * 0.25, baseY - peakHeight * 0.45, x, topY)
        ..quadraticBezierTo(x + halfWidth * 0.25, baseY - peakHeight * 0.45, x + halfWidth, baseY)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color.lerp(_base, const Color(0xFFE85D00), 0.4)!.withValues(alpha: alpha),
              _tip.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromLTWH(x - halfWidth, topY, halfWidth * 2, peakHeight + 2)),
      );
    }
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) => oldDelegate.t != t;
}
