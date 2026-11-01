import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/flashcard_matching_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

/// Thẻ thứ i nằm ở cột i % 2, hàng i ~/ 2. Các cặp: (0,2) (1,3) (4,5) (6,7) (8,9).
const _cardIdOfIndex = [1, 2, 1, 2, 3, 3, 4, 4, 5, 5];

Map<String, dynamic> _game() => {
      'setId': 7,
      'totalPairs': 5,
      'tiles': [
        for (var i = 0; i < _cardIdOfIndex.length; i++)
          {
            'tileId': 't$i',
            'cardId': _cardIdOfIndex[i],
            // Thẻ chẵn là từ, thẻ lẻ cùng cardId là nghĩa.
            'text': 'thẻ $i',
            'type': i.isEven ? 'TERM' : 'MEANING',
          },
      ],
    };

Map<String, dynamic> _largeGame() => {
      'setId': 7,
      'totalPairs': 12,
      'tiles': [
        for (var i = 0; i < 24; i++)
          {
            'tileId': 't$i',
            'cardId': i ~/ 2,
            'text': 'thẻ $i',
            'type': i.isEven ? 'TERM' : 'MEANING',
          },
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // FlashcardService giữ ApiClient của lần dùng đầu nên chỉ cài MockClient một lần.
  var installed = false;
  var gameFactory = _game;

  setUp(() async {
    gameFactory = _game;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    if (!installed) {
      installed = true;
      ApiClient.overrideForTesting(MockClient((request) async {
        final data = request.url.path.endsWith('/matching') ? gameFactory() : <String, dynamic>{};
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));
    }
  });

  Finder tile(int i) => find.byKey(ValueKey('match-tile-t$i'));
  double top(WidgetTester tester, int i) => tester.getTopLeft(tile(i)).dy;
  double left(WidgetTester tester, int i) => tester.getTopLeft(tile(i)).dx;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: FlashcardMatchingScreen(deck: FlashcardSetModel(setId: 7, title: 'Bộ thử')),
    ));
    await tester.pumpAndSettle();
  }

  /// Chạm hai thẻ rồi để thẻ thu nhỏ và các thẻ phía trên rơi xong.
  Future<void> match(WidgetTester tester, int a, int b) async {
    await tester.tap(tile(a));
    await tester.pump();
    await tester.tap(tile(b));
    await tester.pump(const Duration(milliseconds: 2500));
  }

  testWidgets('ban đầu xếp thẻ lần lượt trái, phải theo từng hàng', (tester) async {
    await open(tester);

    expect(find.byIcon(Icons.settings), findsNothing);
    final firstTileSize = tester.getSize(tile(0));
    expect(firstTileSize.height, greaterThan(firstTileSize.width * 0.75));
    expect(left(tester, 0), lessThan(left(tester, 1)));
    expect(left(tester, 0), left(tester, 2));
    expect(top(tester, 0), top(tester, 1));
    expect(top(tester, 2), greaterThan(top(tester, 0)));
    expect(top(tester, 8), top(tester, 9));
  });

  testWidgets('bộ lớn chia thành các lượt 5 cặp và giữ tiến độ toàn bộ', (tester) async {
    gameFactory = _largeGame;
    await open(tester);

    expect(find.text('0 / 12'), findsOneWidget);
    var visible = tester
        .widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned))
        .map((widget) => (widget.key! as ValueKey<String>).value)
        .map((key) => int.parse(key.substring(key.lastIndexOf('t') + 1)))
        .toList();
    expect(visible, hasLength(10));

    final byCard = <int, List<int>>{};
    for (final index in visible) {
      byCard.putIfAbsent(index ~/ 2, () => []).add(index);
    }
    for (final pair in byCard.values) {
      await match(tester, pair[0], pair[1]);
    }

    expect(find.text('5 / 12'), findsOneWidget);
    visible = tester
        .widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned))
        .map((widget) => (widget.key! as ValueKey<String>).value)
        .map((key) => int.parse(key.substring(key.lastIndexOf('t') + 1)))
        .toList();
    expect(visible, hasLength(10));
  });

  testWidgets('thẻ đang chọn có viền màu nhấn như thiết kế', (tester) async {
    await open(tester);
    await tester.tap(tile(0));
    await tester.pump();

    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: tile(0), matching: find.byType(AnimatedContainer)),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, AppPalette.accent);
  });

  testWidgets('ghép đúng liên tiếp tạo streak, ghép sai làm đứt streak', (tester) async {
    await open(tester);

    await match(tester, 8, 9);
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
    await match(tester, 6, 7);
    expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('streak-badge')), matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(tile(0));
    await tester.pump();
    await tester.tap(tile(1));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
  });

  testWidgets('ghép cặp ở hàng dưới cùng: mọi thẻ phía trên rơi xuống một hàng', (tester) async {
    await open(tester);
    final step = top(tester, 2) - top(tester, 0);
    final before = [for (var i = 0; i < 8; i++) top(tester, i)];

    await match(tester, 8, 9);

    for (var i = 0; i < 8; i++) {
      expect(top(tester, i), closeTo(before[i] + step, 0.5), reason: 'thẻ $i phải rơi một hàng');
    }
    // Các thẻ rơi xuống vẫn giữ nguyên cột.
    expect(left(tester, 0), left(tester, 2));
  });

  testWidgets('ghép cặp ở giữa: chỉ các thẻ phía trên rơi, thẻ phía dưới đứng yên', (tester) async {
    await open(tester);
    final step = top(tester, 2) - top(tester, 0);
    final above = [for (var i = 0; i < 4; i++) top(tester, i)];
    final below = [for (var i = 6; i < 10; i++) top(tester, i)];

    await match(tester, 4, 5);

    for (var i = 0; i < 4; i++) {
      expect(top(tester, i), closeTo(above[i] + step, 0.5));
    }
    for (var i = 6; i < 10; i++) {
      expect(top(tester, i), closeTo(below[i - 6], 0.5));
    }
  });

  testWidgets('ghép cặp ở hàng trên cùng: không thẻ nào di chuyển', (tester) async {
    await open(tester);
    final before = [for (var i = 0; i < 10; i++) top(tester, i)];

    await match(tester, 0, 2); // cặp (0,2): cùng cột 0, hàng 0 và 1

    // Thẻ 0 và 2 biến mất; thẻ 4,6,8 (cùng cột) nằm dưới nên không đổi, cột 1 không đổi.
    for (final i in [1, 3, 4, 5, 6, 7, 8, 9]) {
      expect(top(tester, i), closeTo(before[i], 0.5), reason: 'thẻ $i phải đứng yên');
    }
  });

  testWidgets('ghép sai thì không thẻ nào di chuyển', (tester) async {
    await open(tester);
    final before = [for (var i = 0; i < 10; i++) top(tester, i)];

    await tester.tap(tile(0));
    await tester.pump();
    await tester.tap(tile(1)); // khác cardId
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    for (var i = 0; i < 10; i++) {
      expect(top(tester, i), closeTo(before[i], 0.5));
    }
  });

  testWidgets('thẻ đã ghép không còn bấm được', (tester) async {
    await open(tester);
    await match(tester, 8, 9);

    final ignoring = tester.widgetList<IgnorePointer>(
      find.descendant(of: tile(8), matching: find.byType(IgnorePointer)),
    );
    expect(ignoring.any((w) => w.ignoring), isTrue);
  });

  testWidgets('ghép hết các cặp thì hiện hộp chúc mừng, sau khi thẻ cuối biến mất', (tester) async {
    await open(tester);

    await match(tester, 8, 9);
    await match(tester, 6, 7);
    await match(tester, 4, 5);
    await match(tester, 0, 2);
    // Cặp cuối: hộp chúc mừng chưa hiện ngay lúc chạm.
    await tester.tap(tile(1));
    await tester.pump();
    await tester.tap(tile(3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chúc mừng!'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('Chúc mừng!'), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-fireworks')), findsOneWidget);
    expect(find.byKey(const ValueKey('matching-restart')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('matching-restart')));
    await tester.pumpAndSettle();
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('Chúc mừng!'), findsNothing);
  });
}
