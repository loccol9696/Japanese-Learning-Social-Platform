import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_toast.dart';

void main() {
  Widget buildTestableApp({required Widget home}) {
    return MaterialApp(
      navigatorKey: AppToast.navigatorKey,
      home: Scaffold(body: home),
    );
  }

  testWidgets('AppToast.showSuccess renders message and icon', (tester) async {
    await tester.pumpWidget(
      buildTestableApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AppToast.showSuccess('Đăng nhập thành công! Chào mừng testuser');
              },
              child: const Text('Show Toast'),
            );
          },
        ),
      ),
    );

    // Initial state: no toast
    expect(
      find.text('Đăng nhập thành công! Chào mừng testuser'),
      findsNothing,
    );

    // Trigger toast
    await tester.tap(find.text('Show Toast'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish slide down

    // Toast visible
    expect(
      find.text('Đăng nhập thành công! Chào mừng testuser'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Wait until auto-dismiss (2000ms duration + 200ms reverse animation)
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 300));

    // Toast dismissed
    expect(
      find.text('Đăng nhập thành công! Chào mừng testuser'),
      findsNothing,
    );
  });

  testWidgets('AppToast.showError renders error icon and message', (tester) async {
    await tester.pumpWidget(
      buildTestableApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AppToast.showError('Mật khẩu không chính xác');
              },
              child: const Text('Show Error'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mật khẩu không chính xác'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mật khẩu không chính xác'), findsNothing);
  });

  testWidgets('New toast replaces current toast immediately', (tester) async {
    await tester.pumpWidget(
      buildTestableApp(
        home: Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () => AppToast.showInfo('Thông báo 1'),
                  child: const Text('Toast 1'),
                ),
                ElevatedButton(
                  onPressed: () => AppToast.showSuccess('Thông báo 2'),
                  child: const Text('Toast 2'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Toast 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Thông báo 1'), findsOneWidget);

    // Tap toast 2 while toast 1 is still active
    await tester.tap(find.text('Toast 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Thông báo 1'), findsNothing);
    expect(find.text('Thông báo 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thông báo 2'), findsNothing);
  });
}
