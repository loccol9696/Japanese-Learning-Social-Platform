import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/deck_editor_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _card(int id, String term, String meaning) =>
    {'cardId': id, 'setId': 7, 'term': term, 'meaning': meaning};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late List<Map<String, dynamic>> serverCards;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    requests = [];
    serverCards = [];
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final Object data;
      if (request.method == 'GET' && path.endsWith('/flashcards/sets/7/cards')) {
        data = serverCards;
      } else if (request.method == 'POST' && path.endsWith('/flashcards/sets')) {
        data = {'setId': 7, 'title': 'Bộ mới'};
      } else {
        data = <String, dynamic>{};
      }
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> pumpEditor(WidgetTester tester, {FlashcardSetModel? deck}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: DeckEditorScreen(deck: deck)));
    await tester.pumpAndSettle();
  }

  Finder draft(int index) => find.byKey(ValueKey('card-draft-$index'));

  testWidgets('bộ mới: để sẵn 2 ô thẻ trống để nhập ngay', (tester) async {
    await pumpEditor(tester);

    expect(draft(0), findsOneWidget);
    expect(draft(1), findsOneWidget);
    expect(draft(2), findsNothing);
    expect(find.text('Thuật ngữ...'), findsNWidgets(2));
    expect(find.text('Định nghĩa...'), findsNWidgets(2));
  });

  testWidgets('sửa bộ chưa có thuật ngữ nào: cũng để sẵn 2 ô trống', (tester) async {
    await pumpEditor(tester, deck: FlashcardSetModel(setId: 7, title: 'Bộ trống'));

    expect(draft(0), findsOneWidget);
    expect(draft(1), findsOneWidget);
    expect(draft(2), findsNothing);
  });

  testWidgets('sửa bộ đã có thẻ: chỉ hiện các thẻ đó, không thêm ô trống', (tester) async {
    serverCards = [_card(1, '専門', 'chuyên môn'), _card(2, '学校', 'trường học'), _card(3, '先生', 'giáo viên')];
    await pumpEditor(tester, deck: FlashcardSetModel(setId: 7, title: 'N2', totalCards: 3));

    expect(draft(0), findsOneWidget);
    expect(draft(2), findsOneWidget);
    expect(draft(3), findsNothing);
    expect(find.text('専門'), findsOneWidget);
  });

  testWidgets('xoá một ô trống thì còn một ô; xoá nốt thì lại có sẵn 2 ô', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pump();
    expect(draft(0), findsOneWidget);
    expect(draft(1), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pump();
    expect(draft(0), findsOneWidget);
    expect(draft(1), findsOneWidget);
  });

  testWidgets('"Thêm thẻ" vẫn thêm ô thứ ba', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('Thêm thẻ'));
    await tester.pump();

    expect(draft(2), findsOneWidget);
  });

  testWidgets('lưu bộ mới khi còn 2 ô trống: tạo bộ nhưng không tạo thẻ rác', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Bộ mới');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/flashcards/sets')), hasLength(1));
    expect(requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/cards')), isEmpty);
  });

  testWidgets('nhập một ô, để trống ô kia: chỉ lưu thẻ đã nhập', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Bộ mới');
    await tester.enterText(find.descendant(of: draft(0), matching: find.byType(TextField)).first, '猫');
    await tester.enterText(find.descendant(of: draft(0), matching: find.byType(TextField)).last, 'con mèo');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final cardPosts = requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/cards')).toList();
    expect(cardPosts, hasLength(1));
    expect(jsonDecode(cardPosts.single.body)['term'], '猫');
  });

  testWidgets('lưu thiếu tiêu đề: báo bằng toast nổi, không dùng SnackBar ở đáy màn hình', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vui lòng nhập tiêu đề bộ thẻ'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 4)); // đợi toast tự tắt
  });

  testWidgets('tạo bộ thành công: báo "Đã tạo bộ thẻ mới thành công" bằng toast', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Bộ mới');
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Đã tạo bộ thẻ mới thành công'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 4));
  });

  group('kéo đổi chỗ thẻ', () {
    final deck = FlashcardSetModel(setId: 7, title: 'N2', totalCards: 3);

    setUp(() {
      serverCards = [_card(1, '専門', 'chuyên môn'), _card(2, '学校', 'trường học'), _card(3, '先生', 'giáo viên')];
    });

    Future<void> dragFirstBelowSecond(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('card-drag-handle-0'))));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    String termAt(WidgetTester tester, int index) => tester
        .widget<TextField>(find.descendant(of: draft(index), matching: find.byType(TextField)).first)
        .controller!
        .text;

    testWidgets('kéo biểu tượng ⠿ của thẻ đầu xuống thì đổi chỗ và đánh lại số', (tester) async {
      await pumpEditor(tester, deck: deck);
      expect(termAt(tester, 0), '専門');

      await dragFirstBelowSecond(tester);

      expect(termAt(tester, 0), '学校');
      expect(termAt(tester, 1), '専門');
      expect(termAt(tester, 2), '先生');
    });

    testWidgets('lưu sau khi đổi chỗ: gửi thứ tự mới lên server', (tester) async {
      await pumpEditor(tester, deck: deck);
      await dragFirstBelowSecond(tester);

      await tester.tap(find.text('Lưu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final order = requests.where((r) => r.method == 'PUT' && r.url.path.endsWith('/flashcards/sets/7/cards/order'));
      expect(order, hasLength(1));
      expect(jsonDecode(order.single.body), {'ids': [2, 1, 3]});
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('lưu mà không đổi chỗ: không gọi API sắp xếp', (tester) async {
      await pumpEditor(tester, deck: deck);

      await tester.tap(find.text('Lưu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(requests.where((r) => r.url.path.endsWith('/cards/order')), isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
