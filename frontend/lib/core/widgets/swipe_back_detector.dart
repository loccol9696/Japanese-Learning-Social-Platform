import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Vuốt ngang sang phải ở bất kỳ đâu trên màn để quay lại, màn trượt theo ngón tay như khi vuốt giữa các tab.
///
/// Cử chỉ vuốt-từ-cạnh có sẵn của Flutter chỉ nhận trong dải khoảng 20px sát mép trái nên rất khó trúng. Widget này
/// bọc ngoài một [Navigator] và điều khiển hoạt ảnh chuyển trang của màn trên cùng giống cách CupertinoPageRoute làm.
///
/// - Chỉ tác động lên màn là [PageRoute] đang hiển thị xong, không phải hộp thoại / bảng từ dưới lên, không phải
///   màn gốc, và không bị [PopScope] chặn.
/// - Cuộn ngang bên trong màn (PageView, TabBarView, thanh trượt...) nằm sâu hơn nên được ưu tiên trước.
class SwipeBackDetector extends StatefulWidget {
  const SwipeBackDetector({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.enabled = true,
  });

  /// Navigator được điều khiển; phải là Navigator nằm trong [child].
  final GlobalKey<NavigatorState> navigatorKey;

  /// false thì không tạo bộ nhận cử chỉ nào, để cha (ví dụ PageView đổi tab của Home) nhận vuốt ngang.
  final bool enabled;

  final Widget child;

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

/// Vùng mà vuốt bắt đầu từ bên trong nó thì không bao giờ là vuốt-quay-lại (ví dụ thẻ học kéo sang phải để chấm điểm).
///
/// Chắc chắn hơn việc chỉ dựa vào cuộc đua cử chỉ: ngón tay vừa chạm xuống trong vùng này là [SwipeBackDetector]
/// bỏ qua cho tới khi nhấc tay.
class SwipeBackBlocker extends StatelessWidget {
  const SwipeBackBlocker({super.key, required this.child});

  final Widget child;

  /// Các ngón tay đang chạm trong vùng chặn. Gỡ khi nhấc / huỷ qua route toàn cục nên không bị kẹt nếu widget biến
  /// mất giữa chừng (vd. thẻ bay đi rồi được thay bằng thẻ mới).
  static final Set<int> _pressed = {};

  static void _track(PointerDownEvent event) {
    final pointer = event.pointer;
    _pressed.add(pointer);
    final router = GestureBinding.instance.pointerRouter;
    void release(PointerEvent e) {
      if (e is PointerUpEvent || e is PointerCancelEvent) {
        _pressed.remove(pointer);
        router.removeRoute(pointer, release);
      }
    }

    router.addRoute(pointer, release);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _track,
      child: child,
    );
  }
}

/// Cho một màn "nhận" cử chỉ vuốt quay lại khi nó đang ở trạng thái con (ví dụ đang xem video trong cùng trang
/// Khám phá): vuốt thì gọi [onBack] để màn tự thu về trạng thái trước, thay vì đóng cả màn.
///
/// Chỉ có tác dụng khi [active] và màn chứa nó đang là màn trên cùng. Nên dùng cùng [PopScope] (canPop = false khi
/// active) để nút Back của hệ thống cũng hành xử tương tự.
class SwipeBackOverride extends StatefulWidget {
  const SwipeBackOverride({
    super.key,
    required this.active,
    required this.onBack,
    required this.child,
    this.onDragDelta,
    this.onDragEnd,
  });

  final bool active;

  /// Gọi khi vuốt xong để quay lại, nếu màn không dùng [onDragEnd].
  final VoidCallback onBack;

  /// Tuỳ chọn, để nội dung trượt theo ngón tay: nhận phần chiều rộng màn vừa kéo thêm (dương = sang phải).
  final ValueChanged<double>? onDragDelta;

  /// Tuỳ chọn, đi cùng [onDragDelta]: thả tay; true nếu nên quay lại (kéo đủ xa hoặc quẹt đủ nhanh), false nếu nên
  /// trở về chỗ cũ. Khi có hàm này thì [onBack] không được gọi cho cử chỉ vuốt.
  final ValueChanged<bool>? onDragEnd;

  final Widget child;

  /// Cấu hình của màn [top] nếu màn đó đang giữ cử chỉ quay lại; null nếu không.
  static SwipeBackOverride? handlerFor(Route<dynamic>? top) {
    if (top == null) return null;
    for (final state in _entries.reversed) {
      if (state._route == top && state.widget.active) return state.widget;
    }
    return null;
  }

  static final List<_SwipeBackOverrideState> _entries = [];

  @override
  State<SwipeBackOverride> createState() => _SwipeBackOverrideState();
}

class _SwipeBackOverrideState extends State<SwipeBackOverride> {
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    SwipeBackOverride._entries.add(this);
  }

  @override
  void dispose() {
    SwipeBackOverride._entries.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _route = ModalRoute.of(context);
    return widget.child;
  }
}

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  /// Với màn tự xử lý: kéo qua tỉ lệ này của chiều rộng, hoặc quẹt nhanh hơn số lần chiều rộng mỗi giây, là quay lại.
  static const double _overrideFraction = 0.4;
  static const double _overrideVelocity = 1.0;

  Route<dynamic>? _dragRoute;
  bool _dragging = false;
  SwipeBackOverride? _override;
  double _overrideDx = 0;

  NavigatorState? get _navigator => widget.navigatorKey.currentState;

  /// Màn trên cùng. `popUntil` với điều kiện luôn đúng dừng ngay tại màn đầu tiên nên không pop gì cả, chỉ để đọc
  /// route (Navigator không có getter công khai cho việc này).
  static Route<dynamic>? _topRoute(NavigatorState navigator) {
    Route<dynamic>? top;
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    return top;
  }

  /// Bộ điều khiển animation của màn đang hiển thị, để kéo theo ngón tay. `controller` đánh dấu @protected nhưng đây
  /// đúng là cách cử chỉ vuốt lùi của chính Flutter (CupertinoPageRoute) điều khiển chuyển trang.
  static AnimationController? _controllerOf(Route<dynamic>? route) =>
      // ignore: invalid_use_of_protected_member
      route is TransitionRoute ? route.controller : null;

  static bool _canSwipeBack(NavigatorState navigator, Route<dynamic>? route) {
    if (route is! PageRoute ||
        route.fullscreenDialog ||
        !navigator.canPop() ||
        navigator.userGestureInProgress ||
        route.willHandlePopInternally ||
        route.popDisposition != RoutePopDisposition.pop ||
        route.animation?.status != AnimationStatus.completed) {
      return false;
    }
    return _controllerOf(route) != null;
  }

  void _onDragStart(DragStartDetails details) {
    _override = null;
    _dragging = false;
    if (SwipeBackBlocker._pressed.isNotEmpty) return;
    final navigator = _navigator;
    if (navigator == null) return;
    final route = _topRoute(navigator);
    // Màn đang ở trạng thái con tự xử lý việc quay lại: không kéo cả màn, chỉ đo cử chỉ để gọi hàm của nó.
    _override = SwipeBackOverride.handlerFor(route);
    _overrideDx = 0;
    if (_override != null) return;
    if (!_canSwipeBack(navigator, route)) return;
    _dragRoute = route;
    _dragging = true;
    navigator.didStartUserGesture();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final override = _override;
    if (override != null) {
      final delta = details.primaryDelta ?? 0;
      _overrideDx += delta;
      final width = context.size?.width ?? 0;
      if (width > 0) override.onDragDelta?.call(delta / width);
      return;
    }
    if (!_dragging) return;
    final controller = _controllerOf(_dragRoute);
    final width = context.size?.width ?? 0;
    if (controller == null || width <= 0) return;
    // Kéo sang phải làm màn trượt ra: giá trị animation giảm từ 1 về 0.
    controller.value -= (details.primaryDelta ?? 0) / width;
  }

  void _onDragEnd(DragEndDetails details) {
    final override = _override;
    if (override != null) {
      _override = null;
      final width = context.size?.width ?? 1;
      final velocity =
          details.velocity.pixelsPerSecond.dx /
          width; // chiều rộng màn mỗi giây
      final goBack = velocity.abs() >= _overrideVelocity
          ? velocity > 0
          : _overrideDx / width >= _overrideFraction;
      _overrideDx = 0;
      if (override.onDragEnd != null) {
        override.onDragEnd!(goBack);
      } else if (goBack) {
        override.onBack();
      }
      return;
    }
    if (!_dragging) return;
    _dragging = false;
    final navigator = _navigator;
    final controller = _controllerOf(_dragRoute);
    _dragRoute = null;
    if (navigator == null || controller == null) {
      navigator?.didStopUserGesture();
      return;
    }

    final width = context.size?.width ?? 1;
    final velocity =
        details.velocity.pixelsPerSecond.dx / width; // chiều rộng màn mỗi giây
    // Vuốt đủ nhanh thì theo hướng vuốt; chậm thì theo vị trí đã kéo (qua nửa màn thì quay lại).
    final shouldPop = velocity.abs() >= 1.0
        ? velocity > 0
        : controller.value < 0.5;

    if (shouldPop) {
      navigator.pop();
      if (controller.isAnimating) {
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.dismissed ||
              status == AnimationStatus.completed) {
            controller.removeStatusListener(onStatus);
            navigator.didStopUserGesture();
          }
        }

        controller.addStatusListener(onStatus);
      } else {
        navigator.didStopUserGesture();
      }
    } else {
      controller
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .whenComplete(navigator.didStopUserGesture);
    }
  }

  void _onDragCancel() {
    // Cử chỉ bị huỷ giữa chừng: không được coi là yêu cầu quay lại.
    final override = _override;
    if (override != null) {
      _override = null;
      _overrideDx = 0;
      override.onDragEnd?.call(false); // trả nội dung về chỗ cũ
      return;
    }
    _onDragEnd(DragEndDetails(velocity: Velocity.zero));
  }

  @override
  Widget build(BuildContext context) {
    // Luôn bọc GestureDetector để cây widget (và ngăn xếp Navigator bên trong) không bị dựng lại khi `enabled` đổi;
    // không có hàm xử lý thì nó không tạo bộ nhận cử chỉ.
    final enabled = widget.enabled;
    return GestureDetector(
      onHorizontalDragStart: enabled ? _onDragStart : null,
      onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
      onHorizontalDragEnd: enabled ? _onDragEnd : null,
      onHorizontalDragCancel: enabled ? _onDragCancel : null,
      child: widget.child,
    );
  }
}
