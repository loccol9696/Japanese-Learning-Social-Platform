import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_item_model.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/data/services/flashcard_store.dart';
import 'package:frontend/features/flashcard/presentation/screens/deck_overview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final deck = FlashcardSetModel(setId: 101, title: 'N5 Động vật', totalCards: 3);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Cache còn mới → màn hình không gọi API.
    FlashcardStore.instance.seedCardsForTest(101, [
      FlashcardItemModel(cardId: 1, term: '猫', reading: 'ねこ', meaning: 'Con mèo', isStarred: true),
      FlashcardItemModel(cardId: 2, term: '犬', reading: 'いぬ', meaning: 'Con chó'),
      FlashcardItemModel(cardId: 3, term: '学校', meaning: 'Trường học'),
    ]);
    FlashcardStore.instance.seedCardsForTest(102, []);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpDeck(WidgetTester tester, FlashcardSetModel deck) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: DeckOverviewScreen(deck: deck)));
    await settle(tester);
  }

  testWidgets('hiển thị thẻ từ cache, chuyển thẻ bằng nút kế tiếp', (tester) async {
    await pumpDeck(tester, deck);

    expect(find.text('N5 Động vật'), findsOneWidget);
    expect(find.text('3 thuật ngữ'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
    await settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('犬'), findsOneWidget);
  });

  testWidgets('chạm thẻ lật sang mặt sau có cách đọc và nghĩa', (tester) async {
    await pumpDeck(tester, deck);

    await tester.tap(find.text('猫'));
    await settle(tester);
    expect(find.text('ねこ'), findsOneWidget);
    expect(find.text('Con mèo'), findsOneWidget);
  });

  testWidgets('tùy chọn "Chỉ học từ gắn sao" lọc còn thẻ đã gắn sao', (tester) async {
    await pumpDeck(tester, deck);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    await tester.tap(find.text('Chỉ học từ gắn sao'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('猫'), findsOneWidget);
  });

  testWidgets('menu tác giả mở hộp thoại xóa có tên bộ thẻ', (tester) async {
    await pumpDeck(tester, deck);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);
    await tester.tap(find.text('Xóa bộ thẻ'));
    await settle(tester);

    expect(find.text('Xóa bộ thẻ vĩnh viễn?'), findsOneWidget);
    expect(find.textContaining('"N5 Động vật"'), findsOneWidget);
  });

  testWidgets('bộ thẻ trống hiển thị thông báo, không có bộ đếm', (tester) async {
    await pumpDeck(tester, FlashcardSetModel(setId: 102, title: 'Bộ trống'));

    expect(find.text('Chưa có từ vựng trong bộ thẻ'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);
  });
}
