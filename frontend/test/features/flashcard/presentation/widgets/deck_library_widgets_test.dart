import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/widgets/create_deck_tile.dart';
import 'package:frontend/features/flashcard/presentation/widgets/deck_card_item.dart';

void main() {
  testWidgets('CreateDeckTile hiện nhãn và gọi onTap khi bấm', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CreateDeckTile(onTap: () => taps++)),
    ));

    expect(find.text('Tạo bộ thẻ mới'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.byType(CreateDeckTile));
    expect(taps, 1);
  });

  testWidgets('DeckCardItem hiện tên bộ và số thuật ngữ, bấm mở bộ', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeckCardItem(
          deck: FlashcardSetModel(setId: 1, title: 'Từ vựng N5', totalCards: 120),
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.text('Từ vựng N5'), findsOneWidget);
    expect(find.text('120 thuật ngữ'), findsOneWidget);

    await tester.tap(find.text('Từ vựng N5'));
    expect(taps, 1);
  });
}
