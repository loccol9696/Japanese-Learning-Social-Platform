import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A celebratory fireworks layer that runs until the completion dialog closes.
class CompletionFireworks extends StatefulWidget {
  const CompletionFireworks({super.key});

  @override
  State<CompletionFireworks> createState() => _CompletionFireworksState();
}

class _CompletionFireworksState extends State<CompletionFireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          key: const ValueKey('completion-fireworks'),
          painter: _FireworksPainter(_controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _FireworksPainter extends CustomPainter {
  const _FireworksPainter(this.progress);

  final double progress;

  static const _colors = [
    Color(0xFFFFC857),
    Color(0xFFFF5A7A),
    Color(0xFF49D7C4),
    Color(0xFF5C7CFF),
    Color(0xFFD765E8),
    Color(0xFFFF8A34),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bursts = <({Offset center, double delay})>[
      (center: Offset(size.width * .18, size.height * .22), delay: 0),
      (center: Offset(size.width * .82, size.height * .18), delay: .10),
      (center: Offset(size.width * .50, size.height * .30), delay: .22),
      (center: Offset(size.width * .28, size.height * .62), delay: .34),
      (center: Offset(size.width * .76, size.height * .58), delay: .44),
    ];

    for (var burstIndex = 0; burstIndex < bursts.length; burstIndex++) {
      final burst = bursts[burstIndex];
      final local = ((progress - burst.delay) / .56).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final opacity = (1 - Curves.easeIn.transform(local)).clamp(0.0, 1.0);
      final random = math.Random(1907 + burstIndex * 97);

      for (var i = 0; i < 24; i++) {
        final angle = (math.pi * 2 * i / 24) + random.nextDouble() * .18;
        final distance = (58 + random.nextDouble() * 105) * eased;
        final gravity = 72 * local * local;
        final position = burst.center +
            Offset(math.cos(angle) * distance, math.sin(angle) * distance + gravity);
        final length = 5.0 + random.nextDouble() * 7;
        final paint = Paint()
          ..color = _colors[(i + burstIndex) % _colors.length]
              .withValues(alpha: opacity)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(position, position + direction * length, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
