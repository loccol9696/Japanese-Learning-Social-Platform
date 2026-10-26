import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/presentation/screens/messages_tab.dart';

void main() {
  testWidgets('màn con mở trong tab nên vẫn chừa chỗ cho thanh menu dưới', (
    tester,
  ) async {
    // Navigator riêng: push từ trong tab không phủ lên thanh menu của Home.
    final rootKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootKey,
        home: Scaffold(
          body: Stack(
            children: [
              const MessagesTab(bottomInset: 60),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(key: const Key('dock'), height: 60),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('dock')), findsOneWidget);
    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(
        of: find.byType(MessagesTab),
        matching: find.byType(Navigator),
      ),
    );
    tabNavigator.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('chi tiết'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('chi tiết'), findsOneWidget);
    expect(find.byKey(const Key('dock')), findsOneWidget);
    // Chỉ Navigator gốc (1) + Navigator của tab; trang mới nằm trong tab.
    expect(rootKey.currentState!.canPop(), isFalse);
  });
}
