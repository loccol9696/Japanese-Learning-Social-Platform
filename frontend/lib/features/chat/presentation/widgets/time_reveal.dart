import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../chat_format.dart';

/// Quãng kéo để hiện hết giờ gửi.
const double _maxReveal = 56;

/// Vùng sát mép trái dành cho cử chỉ vuốt quay lại của hệ thống.
const double _edgeGestureWidth = 24;

/// Kéo khung chat sang trái để hiện giờ gửi của mọi tin, thả ra thì trở lại.
/// [controller] đi từ 0 (ẩn) đến 1 (hiện hết).
class TimeRevealGesture extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const TimeRevealGesture({
    super.key,
    required this.controller,
    required this.child,
  });

  void _release() {
    controller.animateBack(0, duration: const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _RevealDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_RevealDragRecognizer>(
              _RevealDragRecognizer.new,
              (recognizer) => recognizer
                ..onUpdate = (details) {
                  controller.value -= details.delta.dx / _maxReveal;
                }
                ..onEnd = ((_) {
                  _release();
                })
                ..onCancel = _release,
            ),
      },
      child: child,
    );
  }
}

class _RevealDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx > _edgeGestureWidth && super.isPointerAllowed(event);
}

/// Một hàng tin trong lúc kéo: tin của mình trượt sang trái, giờ gửi hiện ở mép phải.
class TimeRevealRow extends StatelessWidget {
  final Animation<double> animation;
  final DateTime time;
  final bool isMine;
  final Widget child;

  const TimeRevealRow({
    super.key,
    required this.animation,
    required this.time,
    required this.isMine,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final value = animation.value;
        return Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.centerRight,
          children: [
            Transform.translate(
              offset: Offset(isMine ? -_maxReveal * value : 0, 0),
              child: child,
            ),
            if (value > 0)
              Positioned(
                right: 0,
                child: Opacity(
                  opacity: value,
                  child: Text(
                    formatClock(time),
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
