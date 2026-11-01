import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_palette.dart';
import '../chat_format.dart';

/// Quãng kéo để hiện hết giờ gửi.
const double _maxReveal = 56;

/// Quãng vuốt một tin để trả lời; vuốt đủ quãng này rồi thả ra là trả lời.
const double _replySwipeDistance = 72;

/// Vùng sát mép trái dành cho cử chỉ vuốt quay lại của hệ thống.
const double _edgeGestureWidth = 24;

const Duration _releaseDuration = Duration(milliseconds: 180);

/// Cử chỉ kéo ngang trên khung chat: sang trái hiện giờ gửi của mọi tin, sang phải trả
/// lời tin đang vuốt. Gộp một chỗ vì hai cử chỉ cùng trục, tách ra sẽ tranh nhau. Thả
/// tay thì mọi thứ trở về vị trí cũ.
class MessageSwipeGesture extends StatefulWidget {
  /// Đi từ 0 (ẩn giờ) đến 1 (hiện hết).
  final AnimationController timeReveal;

  /// Đi từ 0 đến 1 (vuốt đủ để trả lời).
  final AnimationController replySwipe;

  /// Tin đang được vuốt có trả lời được không.
  final bool Function() canReply;
  final VoidCallback onReply;

  /// Vuốt trả lời đã trở về vị trí cũ.
  final VoidCallback onSettled;
  final Widget child;

  const MessageSwipeGesture({
    super.key,
    required this.timeReveal,
    required this.replySwipe,
    required this.canReply,
    required this.onReply,
    required this.onSettled,
    required this.child,
  });

  @override
  State<MessageSwipeGesture> createState() => _MessageSwipeGestureState();
}

class _MessageSwipeGestureState extends State<MessageSwipeGesture> {
  double _offset = 0;
  bool _armed = false;

  void _onUpdate(DragUpdateDetails details) {
    _offset += details.delta.dx;
    widget.timeReveal.value = (-_offset / _maxReveal).clamp(0.0, 1.0);

    final reply = widget.canReply()
        ? (_offset / _replySwipeDistance).clamp(0.0, 1.0)
        : 0.0;
    widget.replySwipe.value = reply;

    final armed = reply >= 1;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
  }

  void _release() {
    if (_armed) widget.onReply();
    _offset = 0;
    _armed = false;
    widget.timeReveal.animateBack(0, duration: _releaseDuration);
    widget.replySwipe
        .animateBack(0, duration: _releaseDuration)
        .whenComplete(widget.onSettled);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _SwipeRecognizer:
            GestureRecognizerFactoryWithHandlers<_SwipeRecognizer>(
              _SwipeRecognizer.new,
              (recognizer) => recognizer
                ..onUpdate = _onUpdate
                ..onEnd = ((_) {
                  _release();
                })
                ..onCancel = _release,
            ),
      },
      child: widget.child,
    );
  }
}

class _SwipeRecognizer extends HorizontalDragGestureRecognizer {
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx > _edgeGestureWidth && super.isPointerAllowed(event);
}

/// Một hàng tin khi vuốt trả lời: tin trượt sang phải, biểu tượng trả lời hiện ở mép trái.
class ReplySwipeRow extends StatelessWidget {
  final Animation<double> animation;

  /// Hàng này có phải tin đang được vuốt không.
  final bool Function() isActive;
  final Widget child;

  const ReplySwipeRow({
    super.key,
    required this.animation,
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final value = isActive() ? animation.value : 0.0;
        return Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.centerLeft,
          children: [
            if (value > 0)
              Positioned(
                left: 0,
                child: Opacity(
                  opacity: value,
                  child: Icon(
                    Icons.reply_rounded,
                    size: 22,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_replySwipeDistance * value, 0),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// Một hàng tin trong lúc kéo xem giờ: tin của mình trượt sang trái, giờ gửi hiện ở mép
/// phải.
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
