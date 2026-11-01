import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/flame_icon.dart';

/// Hiệu ứng lửa lớn bùng lên từ đáy màn hình, chơi một lần mỗi khi [trigger] tăng lên (dùng khi đạt chuỗi đúng
/// liên tiếp): lửa trồi lên kèm tia lửa bay, banner "N câu đúng liên tiếp!" nảy ra giữa màn hình và máy rung nhẹ.
/// Không chặn cử chỉ chạm.
class FireCelebration extends StatefulWidget {
  const FireCelebration({super.key, required this.trigger, this.streak = 0});

  /// Tăng giá trị này để chơi hiệu ứng.
  final int trigger;

  /// Số câu đúng liên tiếp hiện tại, ghi trên banner (lấy giá trị tại lúc [trigger] tăng). 0 thì không hiện banner.
  final int streak;

  /// Tổng thời gian chơi.
  static const Duration duration = Duration(milliseconds: 2000);

  @override
  State<FireCelebration> createState() => _FireCelebrationState();
}

class _FireCelebrationState extends State<FireCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FireCelebration.duration,
  );

  /// Chuỗi tại lúc bắt đầu chơi, để banner không đổi số giữa chừng nếu chuỗi bị đứt.
  int _shownStreak = 0;

  @override
  void didUpdateWidget(FireCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _shownStreak = widget.streak;
      _controller.forward(from: 0);
      // Rung nhẹ khi đạt mốc; thiết bị không hỗ trợ thì bỏ qua.
      HapticFeedback.heavyImpact().catchError((Object _) {});
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
          if (_controller.isDismissed || _controller.isCompleted) {
            return const SizedBox.shrink();
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: const ValueKey('fire-celebration'),
                  width: double.infinity,
                  height: 260,
                  child: CustomPaint(painter: FirePainter(_controller.value)),
                ),
              ),
              if (_shownStreak > 0)
                Align(
                  alignment: const Alignment(0, -0.2),
                  child: _ComboBanner(
                    key: const ValueKey('fire-banner'),
                    t: _controller.value,
                    streak: _shownStreak,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Dòng chữ "N câu đúng liên tiếp!" nảy ra rồi mờ dần theo tiến trình hiệu ứng [t].
class _ComboBanner extends StatelessWidget {
  const _ComboBanner({super.key, required this.t, required this.streak});

  final double t;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.elasticOut.transform(
      ((t - 0.04) / 0.30).clamp(0.0, 1.0),
    );
    final fadeIn = (t / 0.06).clamp(0.0, 1.0);
    final fadeOut = t > 0.74 ? (1 - (t - 0.74) / 0.26).clamp(0.0, 1.0) : 1.0;
    // Nổi nhẹ lên trong lúc hiện.
    final lift = -14 * Curves.easeOut.transform(t.clamp(0.0, 1.0));
    return Opacity(
      opacity: fadeIn * fadeOut,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: appear,
          // Màn hẹp hoặc chữ lớn thì thu nhỏ banner cho vừa, không tràn ra ngoài.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 32,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB347), Color(0xFFFF5A1F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A18).withValues(alpha: 0.6),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FlameIcon(size: 26, color: Color(0xFFFFF1B8)),
                    const SizedBox(width: 8),
                    Text(
                      '$streak câu đúng liên tiếp!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

  /// Số tia lửa nhỏ bay lên.
  static const int embers = 36;

  static const Color _base = Color(0xFFFF7A00);
  static const Color _tip = Color(0xFFFFC857);

  /// Độ trồi lên (0..1) của cả cụm lửa.
  static double rise(double t) {
    t = t.clamp(0.0, 1.0); // sai số số thực có thể đẩy t vượt 1 một chút, mà Curve.transform không chấp nhận
    if (t < 0.28) {
      return Curves.easeOutBack.transform((t / 0.28).clamp(0.0, 1.0));
    }
    if (t > 0.82) {
      return 1 -
          Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0)) * 0.35;
    }
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
        ..shader =
            RadialGradient(
              colors: [
                _base.withValues(alpha: 0.45 * alpha),
                _base.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: glowCenter, radius: size.width * 0.55),
            ),
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
        ..quadraticBezierTo(
          x - halfWidth * 0.25,
          baseY - peakHeight * 0.45,
          x,
          topY,
        )
        ..quadraticBezierTo(
          x + halfWidth * 0.25,
          baseY - peakHeight * 0.45,
          x + halfWidth,
          baseY,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader =
              LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.lerp(
                    _base,
                    const Color(0xFFE85D00),
                    0.4,
                  )!.withValues(alpha: alpha),
                  _tip.withValues(alpha: alpha),
                ],
              ).createShader(
                Rect.fromLTWH(
                  x - halfWidth,
                  topY,
                  halfWidth * 2,
                  peakHeight + 2,
                ),
              ),
      );
    }

    _paintEmbers(canvas, size, alpha);
  }

  /// Tia lửa nhỏ bay lên từ chân lửa, lắc lư sang hai bên rồi tắt dần. Vị trí cố định theo từng tia nên không giật.
  void _paintEmbers(Canvas canvas, Size size, double alpha) {
    final random = math.Random(2024);
    for (var i = 0; i < embers; i++) {
      final startX = size.width * (0.04 + random.nextDouble() * 0.92);
      final delay = random.nextDouble() * 0.35;
      final speed = 0.55 + random.nextDouble() * 0.9;
      final radius = 1.8 + random.nextDouble() * 3.2;
      final sway = 8 + random.nextDouble() * 16;
      final phase = random.nextDouble() * math.pi * 2;
      final life = ((t - delay) / (1 - delay) * speed).clamp(0.0, 1.0);
      if (life <= 0 || life >= 1) continue;
      final rise = size.height * 1.15 * Curves.easeOut.transform(life);
      final dx = math.sin(life * 7 + phase) * sway;
      canvas.drawCircle(
        Offset(startX + dx, size.height - rise),
        radius * (1 - 0.5 * life),
        Paint()
          ..color = Color.lerp(
            _tip,
            _base,
            life,
          )!.withValues(alpha: alpha * (1 - life))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) => oldDelegate.t != t;
}
