import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/flashcard/data/services/flashcard_store.dart';
import 'package:frontend/features/flashcard/presentation/screens/deck_library_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _set(int id, String title) =>
    {'setId': id, 'title': title, 'totalCards': 3, 'isVideoSaved': false};

// FlashcardService là singleton giữ ApiClient đầu tiên nó thấy: chỉ cài MockClient một lần, đổi hàm xử lý theo test.
Future<http.Response> Function(http.Request request)? _handler;
bool _installed = false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  var failReorder = false;

  setUp(() async {
    if (!_installed) {
      _installed = true;
      ApiClient.overrideForTesting(MockClient((request) => _handler!(request)));
    }
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    FlashcardStore.instance.invalidateAll();
    requests = [];
    failReorder = false;
    _handler = (request) async {
      requests.add(request);
      final path = request.url.path;
      final Object data;
      int status = 200;
      if (path.endsWith('/auth/me') || path.endsWith('/users/me')) {
        data = {'id': 7, 'username': 'sakura', 'email': 'sakura@example.com'};
      } else if (request.method == 'GET' && path.endsWith('/flashcards/sets')) {
        data = {
          'content': [_set(1, 'Bộ A'), _set(2, 'Bộ B'), _set(3, 'Bộ C')],
        };
      } else if (request.method == 'PUT' && path.endsWith('/flashcards/sets/order')) {
        data = <String, dynamic>{};
        if (failReorder) status = 500;
      } else {
        data = <String, dynamic>{};
      }
      return http.Response(
        jsonEncode({'status': status, 'data': data}),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await AuthSession.instance.restore(isAppLaunch: false);
    await tester.pumpWidget(const MaterialApp(home: DeckLibraryScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> longPressDragFirstDown(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text('Bộ A')));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  List<String> titles(WidgetTester tester) {
    final names = ['Bộ A', 'Bộ B', 'Bộ C'];
    names.sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));
    return names;
  }

  testWidgets('nhấn giữ rồi kéo bộ thẻ xuống: đổi chỗ ngay và gửi thứ tự mới lên server', (tester) async {
    await pumpLibrary(tester);
    expect(titles(tester), ['Bộ A', 'Bộ B', 'Bộ C']);

    await longPressDragFirstDown(tester);

    expect(titles(tester), ['Bộ B', 'Bộ A', 'Bộ C']);
    final put = requests.where((r) => r.method == 'PUT' && r.url.path.endsWith('/flashcards/sets/order'));
    expect(put, hasLength(1));
    expect(jsonDecode(put.single.body), {'ids': [2, 1, 3]});
  });

  testWidgets('server lỗi khi lưu thứ tự: trả danh sách về thứ tự cũ', (tester) async {
    failReorder = true;
    await pumpLibrary(tester);

    await longPressDragFirstDown(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(titles(tester), ['Bộ A', 'Bộ B', 'Bộ C']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('đang tìm kiếm thì không kéo đổi chỗ', (tester) async {
    await pumpLibrary(tester);
    await tester.enterText(find.byType(TextField), 'Bộ');
    await tester.pumpAndSettle();

    await longPressDragFirstDown(tester);

    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('kéo biểu tượng ⠿ của bộ thẻ (không cần nhấn giữ) cũng đổi chỗ', (tester) async {
    await pumpLibrary(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('deck-drag-handle-1'))));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(titles(tester), ['Bộ B', 'Bộ A', 'Bộ C']);
    expect(requests.where((r) => r.method == 'PUT' && r.url.path.endsWith('/sets/order')), hasLength(1));
  });

  testWidgets('đang tìm kiếm thì ẩn biểu tượng kéo', (tester) async {
    await pumpLibrary(tester);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));

    await tester.enterText(find.byType(TextField), 'Bộ');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });
}
