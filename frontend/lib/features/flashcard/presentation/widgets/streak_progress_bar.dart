import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/flame_icon.dart';
import 'answer_streak.dart';

/// Mức "nhiệt" của ngọn lửa theo chuỗi đúng liên tiếp: càng dài lửa càng to và càng rực, luôn giữ tông cam.
class StreakHeat {
  const StreakHeat._({
    required this.tip,
    required this.base,
    required this.core,
    required this.glow,
    required this.barStart,
    required this.barEnd,
    required this.text,
    required this.size,
    required this.sparks,
  });

  final Color tip;
  final Color base;
  final Color core;
  final Color glow;
  final Color barStart;
  final Color barEnd;
  final Color text;

  /// Cỡ ngọn lửa (px).
  final double size;

  /// Số tia lửa bắn ra mỗi lần tăng chuỗi.
  final int sparks;

  static const StreakHeat warm = StreakHeat._(
    tip: Color(0xFFFFD27A),
    base: Color(0xFFFF8A1F),
    core: Color(0xFFFFF1B8),
    glow: Color(0xFFFF9E2C),
    barStart: Color(0xFFFFB347),
    barEnd: Color(0xFFFF7A18),
    text: Color(0xFF1A1033),
    size: 32,
    sparks: 8,
  );

  static const StreakHeat hot = StreakHeat._(
    tip: Color(0xFFFFC857),
    base: Color(0xFFFF4D1F),
    core: Color(0xFFFFE9A8),
    glow: Color(0xFFFF6A1F),
    barStart: Color(0xFFFFC857),
    barEnd: Color(0xFFFF5A1F),
    text: Color(0xFF1A1033),
    size: 38,
    sparks: 12,
  );

  static const StreakHeat blaze = StreakHeat._(
    tip: Color(0xFFFFC857),
    base: Color(0xFFFF4D1F),
    core: Color(0xFFFFE9A8),
    glow: Color(0xFFFF6A1F),
    barStart: Color(0xFFFFC857),
    barEnd: Color(0xFFFF5A1F),
    text: Color(0xFF1A1033),
    size: 42,
    sparks: 16,
  );

  /// Mức nhiệt của một chuỗi: chuỗi càng dài thì lửa càng lớn và nhiều tia hơn, nhưng luôn giữ màu cam.
  static StreakHeat of(int streak) {
    if (streak >= AnswerStreak.fireEvery * 2) return blaze;
    if (streak >= AnswerStreak.fireEvery) return hot;
    return warm;
  }
}

/// Thanh tiến trình của phiên luyện tập. Bình thường là màu nhấn; khi trả lời đúng liên tiếp
/// ([AnswerStreak.highlightFrom] câu trở lên) thì đổi sang màu lửa và hiện ngọn lửa mang số chuỗi ở đầu thanh.
///
/// Ngọn lửa luôn lập lòe; mỗi câu đúng làm nó nảy lên và bắn tia lửa, lần bắt lửa đầu tiên bùng ra từ không,
/// còn đứt chuỗi thì lửa tắt kèm khói. Chuỗi càng dài lửa càng to và rực hơn (xem [StreakHeat]).
class StreakProgressBar extends StatefulWidget {
  const StreakProgressBar({
    super.key,
    required this.progress,
    this.streak = 0,
    this.height = 8,
  });

  /// 0..1
  final double progress;

  /// Số câu đúng liên tiếp.
  final int streak;
  final double height;

  @override
  State<StreakProgressBar> createState() => _StreakProgressBarState();
}

class _StreakProgressBarState extends State<StreakProgressBar>
    with TickerProviderStateMixin {
  /// Lửa lập lòe (chạy qua lại), dừng sau một lúc để không chạy mãi khi người dùng đứng yên.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// Nảy lên mỗi câu đúng / bùng lên lần đầu bắt lửa. Bắt đầu ở trạng thái đã xong (value = 1).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  /// Tia lửa bắn ra.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  /// Lửa tắt khi đứt chuỗi.
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );

  bool _igniting = false;
  int _burstSerial = 0;

  /// Chuỗi ngay trước khi đứt, để vẽ ngọn lửa đang tắt đúng cỡ và đúng số.
  int _lastStreak = 0;

  bool get _highlighted => widget.streak >= AnswerStreak.highlightFrom;

  @override
  void initState() {
    super.initState();
    if (_highlighted) _startIdle();
  }

  @override
  void didUpdateWidget(StreakProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasHighlighted = oldWidget.streak >= AnswerStreak.highlightFrom;
    if (_highlighted && widget.streak > oldWidget.streak) {
      _igniting = !wasHighlighted;
      _burstSerial++;
      _out.value = 1;
      _pop.forward(from: 0);
      _burst.forward(from: 0);
      _startIdle();
    } else if (!_highlighted && wasHighlighted) {
      _lastStreak = oldWidget.streak;
      _idle.stop();
      _out.forward(from: 0);
    }
  }

  void _startIdle() {
    _idle.repeat(reverse: true, count: 20);
  }

  @override
  void dispose() {
    _idle.dispose();
    _pop.dispose();
    _burst.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.progress.clamp(0.0, 1.0);
    final heat = StreakHeat.of(widget.streak);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: value, end: value),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            final fillWidth = width * animated;
            return SizedBox(
              height: widget.height,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Đường nền
                  Container(
                    key: const ValueKey('progress-track'),
                    decoration: BoxDecoration(
                      color: AppPalette.border.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(widget.height),
                    ),
                  ),
                  // Phần đã hoàn thành: có ánh sáng lan ra và vệt sáng chạy khi đang có chuỗi
                  // Bề rộng lấy thẳng từ `animated` (đã được làm mượt ở trên) để màu và ngọn lửa luôn đi cùng nhau;
                  // AnimatedContainer chỉ làm mượt việc đổi màu / ánh sáng, không làm mượt thêm bề rộng.
                  SizedBox(
                    width: fillWidth,
                    height: widget.height,
                    child: AnimatedContainer(
                      key: ValueKey(
                        _highlighted ? 'progress-fill-fire' : 'progress-fill',
                      ),
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height),
                        gradient: _highlighted
                            ? LinearGradient(
                                colors: [heat.barStart, heat.barEnd],
                              )
                            : null,
                        color: _highlighted
                            ? null
                            : AppPalette.accent.withValues(alpha: 0.55),
                        boxShadow: _highlighted
                            ? [
                                BoxShadow(
                                  color: heat.glow.withValues(alpha: 0.55),
                                  blurRadius: 12,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                      child: _highlighted
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                widget.height,
                              ),
                              child: AnimatedBuilder(
                                animation: _idle,
                                builder: (context, _) => CustomPaint(
                                  size: Size.infinite,
                                  painter: _SheenPainter(_idle.value),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_highlighted) _buildBadge(heat, fillWidth, width),
                  // Lửa đang tắt chỉ tồn tại trong lúc hoạt ảnh chạy.
                  AnimatedBuilder(
                    animation: _out,
                    builder: (context, _) => !_highlighted && _out.isAnimating
                        ? _buildExtinguishing(fillWidth, width)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Vị trí ngang của ngọn lửa: ở đầu phần đã hoàn thành, không tràn ra ngoài thanh.
  double _leftFor(double size, double fillWidth, double width) =>
      (fillWidth - size / 2).clamp(0.0, math.max(0.0, width - size));

  double _topFor(double size) => widget.height / 2 - size / 2 - 4;

  /// Ngọn lửa kèm số chuỗi, lập lòe, nảy lên mỗi câu đúng và bắn tia lửa.
  Widget _buildBadge(StreakHeat heat, double fillWidth, double width) {
    final size = heat.size;
    return Positioned(
      left: _leftFor(size, fillWidth, width),
      top: _topFor(size),
      child: SizedBox(
        key: const ValueKey('streak-badge'),
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Tia lửa bắn ra khi tăng chuỗi; xong thì tự gỡ khỏi cây widget.
            Positioned(
              left: -size,
              top: -size,
              width: size * 3,
              height: size * 3,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) => _burst.value >= 1
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          key: const ValueKey('streak-sparks'),
                          painter: _SparkPainter(
                            t: _burst.value,
                            count: _igniting ? heat.sparks * 2 : heat.sparks,
                            seed: _burstSerial,
                            colors: [heat.tip, heat.base, heat.core],
                          ),
                        ),
                ),
              ),
            ),
            // Ngọn lửa + số, nảy lên
            AnimatedBuilder(
              animation: _pop,
              builder: (context, child) {
                final elastic = Curves.elasticOut.transform(
                  _pop.value.clamp(0.0, 1.0),
                );
                // Bắt lửa lần đầu: từ không bùng lên; các lần sau: phóng to rồi co về.
                final scale = _igniting ? elastic : 1.55 - 0.55 * elastic;
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _idle,
                    builder: (context, _) =>
                        _Flame(heat: heat, wave: _idle.value, size: size),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: size * 0.3),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        '${widget.streak}',
                        key: ValueKey(widget.streak),
                        style: TextStyle(
                          color: heat.text,
                          fontSize: size * 0.37,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lửa tắt: nhỏ dần, xám dần, mờ dần và bốc vài làn khói lên.
  Widget _buildExtinguishing(double fillWidth, double width) {
    final heat = StreakHeat.of(_lastStreak);
    final size = heat.size;
    return Positioned(
      left: _leftFor(size, fillWidth, width),
      top: _topFor(size),
      child: IgnorePointer(
        child: SizedBox(
          key: const ValueKey('streak-badge-out'),
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _out,
            builder: (context, _) {
              final t = _out.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -size,
                    top: -size * 1.4,
                    width: size * 3,
                    height: size * 3,
                    child: CustomPaint(painter: _SmokePainter(t)),
                  ),
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 - 0.45 * t,
                      alignment: Alignment.bottomCenter,
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: _FlamePainter(
                          heat: heat,
                          wave: 0,
                          tint: Color.lerp(null, const Color(0xFF8A8FA8), t),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ngọn lửa lập lòe: giãn và hẹp nhẹ, nghiêng qua lại quanh chân lửa.
class _Flame extends StatelessWidget {
  const _Flame({required this.heat, required this.wave, required this.size});

  final StreakHeat heat;

  /// 0..1 (đi qua lại)
  final double wave;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = math.sin(wave * math.pi);
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..scaleByDouble(1 - 0.05 * s, 1 + 0.09 * s, 1, 1)
        ..rotateZ(0.09 * math.sin(wave * math.pi * 2)),
      child: CustomPaint(
        size: Size.square(size),
        painter: _FlamePainter(heat: heat, wave: wave),
      ),
    );
  }
}

/// Vẽ ánh sáng toả, thân lửa chuyển màu từ ngọn xuống chân và lõi sáng bên trong.
class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.heat, required this.wave, this.tint});

  final StreakHeat heat;
  final double wave;

  /// Khi lửa tắt: màu xám trộn dần vào.
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.sin(wave * math.pi);
    Color mix(Color c) => tint == null ? c : Color.lerp(c, tint, 0.85)!;

    // Ánh sáng toả phía sau, nhấp nháy theo nhịp lửa
    final glowCenter = Offset(size.width / 2, size.height * 0.62);
    final glowRadius = size.width * (0.78 + 0.1 * s);
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            mix(heat.glow)
                .withValues(alpha: tint == null ? 0.42 + 0.14 * s : 0.12),
            mix(heat.glow).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    final body = FlamePainter.buildPath(size);
    canvas.drawPath(
      body,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mix(heat.tip), mix(heat.base)],
        ).createShader(Offset.zero & size),
    );

    // Lõi sáng: bản thu nhỏ của thân lửa, đặt thấp hơn
    final anchor = Offset(size.width / 2, size.height * 0.96);
    final coreScale = 0.5 + 0.04 * s;
    final matrix = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(coreScale, coreScale, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
    canvas.drawPath(
      body.transform(matrix.storage),
      Paint()
        ..isAntiAlias = true
        ..color = mix(heat.core).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) =>
      oldDelegate.wave != wave ||
      oldDelegate.heat != heat ||
      oldDelegate.tint != tint;
}

/// Vệt sáng chạy dọc phần đã hoàn thành của thanh khi đang có chuỗi.
class _SheenPainter extends CustomPainter {
  _SheenPainter(this.t);

  /// 0..1
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    const band = 44.0;
    final x = -band + t * (size.width + band * 2);
    canvas.drawRect(
      Rect.fromLTWH(x, 0, band, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(x, 0, band, size.height)),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter oldDelegate) => oldDelegate.t != t;
}

/// Tia lửa bắn lên và toả ra từ ngọn lửa, rơi nhẹ rồi mờ dần. Vị trí ngẫu nhiên nhưng cố định theo [seed],
/// nên không giật giữa các khung hình.
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.t,
    required this.count,
    required this.seed,
    required this.colors,
  });

  final double t;
  final int count;
  final int seed;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed * 7919 + 13);
    final origin = Offset(size.width / 2, size.height / 2);
    final reach = size.width / 2;
    final eased = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

    for (var i = 0; i < count; i++) {
      // Phần lớn bay lên, lệch hai bên.
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.5;
      final distance = reach * (0.45 + random.nextDouble() * 0.55);
      final radius = 1.6 + random.nextDouble() * 2.6;
      final color = colors[random.nextInt(colors.length)];
      final fall = 14 * t * t; // trọng lực nhẹ
      final position =
          origin +
          Offset(math.cos(angle), math.sin(angle)) * distance * eased +
          Offset(0, fall);
      final alpha = (1 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        position,
        radius * (1 - 0.6 * t),
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.t != t;
}

/// Vài làn khói xám bốc lên khi lửa tắt.
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    const puffs = [(-9.0, 0.0), (0.0, 0.12), (9.0, 0.05)];
    for (var i = 0; i < puffs.length; i++) {
      final (dx, delay) = puffs[i];
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final rise = 26 * Curves.easeOut.transform(local);
      canvas.drawCircle(
        origin + Offset(dx * (1 + local * 0.6), -rise),
        3 + 5 * local,
        Paint()
          ..color = const Color(0xFFB4B8CC)
              .withValues(alpha: 0.38 * (1 - local)),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter oldDelegate) => oldDelegate.t != t;
}
