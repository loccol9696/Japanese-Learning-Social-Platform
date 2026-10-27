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

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  Route<dynamic>? _dragRoute;
  bool _dragging = false;

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
    final navigator = _navigator;
    if (navigator == null) return;
    final route = _topRoute(navigator);
    if (!_canSwipeBack(navigator, route)) return;
    _dragRoute = route;
    _dragging = true;
    navigator.didStartUserGesture();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final controller = _controllerOf(_dragRoute);
    final width = context.size?.width ?? 0;
    if (controller == null || width <= 0) return;
    // Kéo sang phải làm màn trượt ra: giá trị animation giảm từ 1 về 0.
    controller.value -= (details.primaryDelta ?? 0) / width;
  }

  void _onDragEnd(DragEndDetails details) {
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
    final velocity = details.velocity.pixelsPerSecond.dx / width; // chiều rộng màn mỗi giây
    // Vuốt đủ nhanh thì theo hướng vuốt; chậm thì theo vị trí đã kéo (qua nửa màn thì quay lại).
    final shouldPop = velocity.abs() >= 1.0 ? velocity > 0 : controller.value < 0.5;

    if (shouldPop) {
      navigator.pop();
      if (controller.isAnimating) {
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.dismissed || status == AnimationStatus.completed) {
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
          .animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
          .whenComplete(navigator.didStopUserGesture);
    }
  }

  void _onDragCancel() => _onDragEnd(DragEndDetails(velocity: Velocity.zero));

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
