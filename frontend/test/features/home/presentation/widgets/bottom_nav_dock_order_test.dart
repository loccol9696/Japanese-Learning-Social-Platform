import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/presentation/widgets/bottom_nav_dock.dart';

void main() {
  testWidgets('thứ tự tab: Trang chủ, Flashcard, +, Tin nhắn, Cá nhân', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavDock(selectedIndex: 0, onTabSelected: (_) {}),
      ),
    ));

    double x(String label) => tester.getCenter(find.text(label)).dx;

    expect(x('Trang chủ') < x('Flashcard'), isTrue);
    expect(x('Flashcard') < x('Tin nhắn'), isTrue);
    expect(x('Tin nhắn') < x('Cá nhân'), isTrue);
    // Nút + nằm giữa Flashcard và Tin nhắn.
    final plus = tester.getCenter(find.byIcon(Icons.add_rounded)).dx;
    expect(x('Flashcard') < plus && plus < x('Tin nhắn'), isTrue);
  });

  testWidgets('bấm từng tab trả đúng chỉ số', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavDock(selectedIndex: 0, onTabSelected: tapped.add),
      ),
    ));

    await tester.tap(find.text('Flashcard'));
    await tester.tap(find.text('Tin nhắn'));

    expect(tapped, [BottomNavDock.flashcardIndex, BottomNavDock.messagesIndex]);
    expect(BottomNavDock.flashcardIndex, 1);
    expect(BottomNavDock.messagesIndex, 3);
  });
}
