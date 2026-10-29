import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/onboarding/presentation/onboarding_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _status({String? level, List<int> topics = const []}) => {
  'needed': true,
  'completed': false,
  'skipCount': 0,
  'maxSkips': 2,
  'jlptLevel': level,
  'topicIds': topics,
  'availableTopics': [
    {'id': 1, 'name': 'Anime & Manga'},
    {'id': 2, 'name': 'Giao tiếp hằng ngày'},
    {'id': 3, 'name': 'Luyện thi JLPT'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late Map<String, dynamic> Function(http.Request request) respond;
  var finished = 0;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(
      accessToken: _jwt(),
      refreshToken: 'r',
    );
    requests = [];
    finished = 0;
    respond = (_) => _status();
    ApiClient.overrideForTesting(
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'status': 200, 'data': respond(request)}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () => finished++)),
    );
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.byKey(const ValueKey('onboarding-continue'));

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(continueButton()).onPressed != null;

  testWidgets('bước 1: chỉ bấm được Tiếp tục sau khi chọn trình độ', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Trình độ tiếng Nhật của bạn?'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('level-N3')));
    await tester.pump();
    expect(continueEnabled(tester), isTrue);
  });

  testWidgets(
    'bước 2: phải chọn ít nhất một sở thích, rồi lưu đúng nội dung và kết thúc',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('level-N3')));
      await tester.pump();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(find.text('Sở thích của bạn là gì?'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.tap(find.byKey(const ValueKey('topic-1')));
      await tester.tap(find.byKey(const ValueKey('topic-3')));
      await tester.pump();
      expect(continueEnabled(tester), isTrue);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      final put = requests.where((r) => r.method == 'PUT');
      expect(put, hasLength(1));
      final body = jsonDecode(put.single.body) as Map<String, dynamic>;
      expect(body['jlptLevel'], 'N3');
      expect(body['topicIds'], unorderedEquals([1, 3]));
      expect(finished, 1);
    },
  );

  testWidgets('bỏ qua gọi đúng endpoint bỏ qua và kết thúc, không lưu gì', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    final skip = requests.where(
      (r) => r.method == 'POST' && r.url.path.endsWith('/onboarding/skip'),
    );
    expect(skip, hasLength(1));
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(finished, 1);
  });

  testWidgets('nút "‹" ở bước 2 chỉ quay về bước 1 và giữ đáp án đã chọn', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('level-N2')));
    await tester.pump();
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Trình độ tiếng Nhật của bạn?'), findsOneWidget);
    expect(continueEnabled(tester), isTrue); // N2 vẫn được chọn
    expect(finished, 0);
  });

  testWidgets('không thoát được bằng nút Back hệ thống', (tester) async {
    await pump(tester);

    final scope = tester.widget<PopScope>(find.byType(PopScope).first);
    expect(scope.canPop, isFalse);
  });

  testWidgets('đáp án cũ được điền sẵn', (tester) async {
    respond = (_) => _status(level: 'N4', topics: [2]);
    await pump(tester);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(
      continueEnabled(tester),
      isTrue,
    ); // đã có sở thích 2 nên được tiếp tục ngay
  });

  testWidgets('lưu lỗi mạng thì ở lại màn hình, không kết thúc', (
    tester,
  ) async {
    ApiClient.overrideForTesting(
      MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') throw Exception('offline');
        return http.Response(
          jsonEncode({'status': 200, 'data': _status()}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('level-N5')));
    await tester.pump();
    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-2')));
    await tester.pump();

    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(finished, 0);
    expect(find.text('Sở thích của bạn là gì?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
