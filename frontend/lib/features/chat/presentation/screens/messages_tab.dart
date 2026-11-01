import 'package:flutter/material.dart';

import '../../../../core/widgets/swipe_back_detector.dart';
import 'inbox_screen.dart';

/// Tab Tin nhắn của màn Home. Có Navigator riêng nên hộp thư, cuộc trò chuyện, tin nhắn mới...
/// đều mở bên trong tab. Thanh menu dưới của Home hiện ở hộp thư và ẩn khi đang ở một màn con.
class MessagesTab extends StatefulWidget {
  /// Chiều cao thanh menu dưới (đã gồm vùng an toàn) đang che phía dưới tab; 0 khi thanh bị ẩn.
  final double bottomInset;

  /// Báo khi đang ở trong một màn con của tab (khung chat, trang cá nhân...) hay đã về hộp thư;
  /// Home dùng để ẩn thanh menu dưới khi đang nhắn tin.
  final ValueChanged<bool>? onChildRouteChanged;

  const MessagesTab({super.key, required this.bottomInset, this.onChildRouteChanged});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

/// Đánh dấu các màn nằm trong tab Tin nhắn: tab được giữ sống khi chuyển sang tab
/// khác, nên những màn này còn phải xét tab có đang hiển thị hay không.
class MessagesTabScope extends InheritedWidget {
  const MessagesTabScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MessagesTabScope>() != null;

  @override
  bool updateShouldNotify(MessagesTabScope oldWidget) => false;
}

class _MessagesTabState extends State<MessagesTab> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _ChildRouteObserver _observer = _ChildRouteObserver(_onRouteChanged);

  /// Đang ở một màn con (khung chat...) chứ không phải hộp thư.
  bool _childOpen = false;

  void _onRouteChanged(bool open) {
    // Hoãn tới sau khung hình để không setState của Home giữa lúc Navigator đang dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open != _childOpen) setState(() => _childOpen = open);
      widget.onChildRouteChanged?.call(open);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      // Thanh menu đang hiện thì vùng an toàn phía dưới đã được chừa cho nó, tránh chừa thêm lần nữa trong các
      // màn con. Thanh menu ẩn (bottomInset = 0) thì giữ nguyên để ô nhập không đè lên thanh cử chỉ.
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: widget.bottomInset > 0,
        // Nút Back của hệ thống quay lại trong tab trước, hết màn con mới thoát ra ngoài.
        child: NavigatorPopHandler(
          onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
          child: MessagesTabScope(
            child: Navigator(
              key: _navigatorKey,
              observers: [_observer],
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
            ),
          ),
        ),
      ),
    );

    // Ở màn con, vuốt ngang sang phải ở bất kỳ đâu = quay lại hộp thư (thay vì để Home chuyển sang tab bên cạnh).
    // Ở hộp thư thì tắt để Home nhận vuốt đổi tab.
    return SwipeBackDetector(
      key: const ValueKey('messages-back-swipe'),
      navigatorKey: _navigatorKey,
      enabled: _childOpen,
      child: content,
    );
  }
}

/// Báo tab đang ở màn con hay ở hộp thư, dựa vào tuyến nằm ngay dưới thay vì tự đếm số tuyến: cách đếm sẽ lệch
/// nếu observer được gắn sau khi hộp thư đã mở (ví dụ Hot Reload), còn cách này luôn đúng.
class _ChildRouteObserver extends NavigatorObserver {
  _ChildRouteObserver(this._onChanged);

  final ValueChanged<bool> _onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      // Có tuyến nằm dưới nghĩa là tuyến mới là màn con của hộp thư.
      _onChanged(previousRoute != null);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      // Tuyến lộ ra mà là tuyến gốc (hộp thư) thì đã thoát hết màn con.
      _onChanged(previousRoute != null && !previousRoute.isFirst);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChanged(previousRoute != null && !previousRoute.isFirst);
}
