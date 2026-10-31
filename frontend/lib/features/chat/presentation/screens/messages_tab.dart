import 'package:flutter/material.dart';

import 'inbox_screen.dart';

/// Tab Tin nhắn của màn Home. Có Navigator riêng nên hộp thư, cuộc trò chuyện, tin nhắn mới...
/// đều mở bên trong tab và thanh menu dưới của Home luôn hiện.
class MessagesTab extends StatefulWidget {
  /// Chiều cao thanh menu dưới (đã gồm vùng an toàn) đang che phía dưới tab; 0 khi thanh bị ẩn.
  final double bottomInset;

  const MessagesTab({super.key, required this.bottomInset});

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      // Vùng an toàn phía dưới đã được chừa cho thanh menu, tránh chừa thêm lần nữa trong các màn con.
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        // Nút Back của hệ thống quay lại trong tab trước, hết màn con mới thoát ra ngoài.
        child: NavigatorPopHandler(
          onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
          child: MessagesTabScope(
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
            ),
          ),
        ),
      ),
    );
  }
}
