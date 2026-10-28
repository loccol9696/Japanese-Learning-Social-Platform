import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/square_add_button.dart';

void main() {
  testWidgets('SquareAddButton là ô vuông có dấu +, bấm gọi onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: SquareAddButton(tooltip: 'Tạo mới', onPressed: () => taps++)),
      ),
    ));

    final size = tester.getSize(find.byType(SquareAddButton));
    expect(size.width, size.height);
    expect(size.width, SquareAddButton.size);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byTooltip('Tạo mới'), findsOneWidget);

    await tester.tap(find.byType(SquareAddButton));
    expect(taps, 1);
  });
}
