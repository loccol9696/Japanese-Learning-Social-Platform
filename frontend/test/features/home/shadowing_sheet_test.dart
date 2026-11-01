import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/home/data/services/speech_recognizer.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/presentation/screens/shadowing_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecognizer implements SpeechRecognizer {
  bool available = true;
  void Function(String text)? _onFinal;

  /// Giả lập trình nhận dạng trả kết quả cuối cùng cho câu vừa nói.
  void finish(String text) => _onFinal?.call(text);

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start({
    required Duration listenFor,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(double level) onLevel,
    required void Function(String code) onError,
  }) async {
    _onFinal = onFinal;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

const _cues = [
  SubtitleCue(
    start: Duration(seconds: 0),
    end: Duration(seconds: 3),
    text: '私の名前はロックです。',
    translation: 'Tên tôi là Lộc.',
  ),
  SubtitleCue(
    start: Duration(seconds: 4),
    end: Duration(seconds: 7),
    text: '今日は日本語を勉強します。',
    translation: 'Hôm nay học tiếng Nhật.',
  ),
];

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

/// Dựng bảng trực tiếp trong một Scaffold để kiểm tra nội dung.
Widget _app(SpeechRecognizer recognizer, {List<SubtitleCue> cues = _cues, ValueChanged<Map<int, int>>? onScores}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ShadowingSheet(
            videoId: '1',
            cues: cues,
            recognizer: recognizer,
            onScoresChanged: onScores,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    ApiClient.overrideForTesting(MockClient((request) async {
      final lineIndex = request.url.path.contains('/lines/1/') ? 1 : 0;
      return http.Response(
        jsonEncode({
          'status': 200,
          'data': {
            'lineIndex': lineIndex,
            'expectedText': _cues[lineIndex].text,
            'recognizedText': _cues[lineIndex].text,
            'score': 86,
            'level': 'GOOD',
            'words': [
              {'text': _cues[lineIndex].text, 'correct': true},
            ],
            'bestScore': 86,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  testWidgets('trạng thái chờ: tiêu đề, nút đóng, câu, bản dịch, nghe mẫu và micro', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()));

    expect(find.text('Luyện nói theo'), findsOneWidget);
    expect(find.byKey(const ValueKey('shadowing-close')), findsOneWidget);
    expect(find.text('私の名前はロックです。'), findsOneWidget);
    expect(find.text('Tên tôi là Lộc.'), findsOneWidget);
    expect(find.text('Nghe mẫu'), findsOneWidget);
    expect(find.text('Chạm để bắt đầu nói'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('bấm micro thì chuyển sang đang nghe, có nút dừng', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()));

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(find.text('Đang nghe bạn nói...'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('thiết bị không hỗ trợ thì báo lỗi dễ hiểu', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()..available = false));

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(find.textContaining('chưa hỗ trợ nhận dạng giọng nói'), findsOneWidget);
    expect(find.text('Chạm để thử lại'), findsOneWidget);
  });

  testWidgets('video không có kịch bản', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer(), cues: const []));

    expect(find.textContaining('chưa có kịch bản'), findsOneWidget);
  });

  testWidgets('nói xong: hiện điểm, Thử lại và Câu tiếp theo; điểm được báo về màn bên dưới', (tester) async {
    final recognizer = _FakeRecognizer();
    final reported = <Map<int, int>>[];
    await tester.pumpWidget(_app(recognizer, onScores: reported.add));

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    recognizer.finish('私の名前はロックです');
    await tester.pumpAndSettle();

    expect(find.text('86%'), findsOneWidget);
    expect(find.text('giống bản gốc'), findsOneWidget);
    expect(find.byKey(const ValueKey('shadowing-retry')), findsOneWidget);
    expect(find.text('Câu tiếp theo'), findsOneWidget);
    expect(reported.last, {0: 86});
  });

  testWidgets('"Thử lại" quay về trạng thái chờ, "Câu tiếp theo" sang câu kế', (tester) async {
    final recognizer = _FakeRecognizer();
    await tester.pumpWidget(_app(recognizer));
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    recognizer.finish('私の名前はロックです');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shadowing-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Chạm để bắt đầu nói'), findsOneWidget);
    expect(find.text('私の名前はロックです。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    recognizer.finish('私の名前はロックです');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shadowing-next')));
    await tester.pumpAndSettle();

    expect(find.text('今日は日本語を勉強します。'), findsOneWidget);
    expect(find.text('Chạm để bắt đầu nói'), findsOneWidget);
  });

  group('showShadowingSheet', () {
    testWidgets('mở ngay trên trang hiện tại dưới dạng bảng, nút X đóng bảng', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kịch bản'),
                  ElevatedButton(
                    onPressed: () => showShadowingSheet(
                      context,
                      videoId: '1',
                      cues: _cues,
                      recognizer: _FakeRecognizer(),
                    ),
                    child: const Text('luyện nói'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('luyện nói'));
      await tester.pumpAndSettle();

      expect(find.text('Luyện nói theo'), findsOneWidget);
      // Trang Kịch bản vẫn nằm ngay bên dưới, không bị thay bằng một trang khác.
      expect(find.text('Kịch bản'), findsOneWidget);
      final sheetTop = tester.getTopLeft(find.byType(ShadowingSheet)).dy;
      expect(sheetTop, greaterThan(100));

      await tester.tap(find.byKey(const ValueKey('shadowing-close')));
      await tester.pumpAndSettle();

      expect(find.text('Luyện nói theo'), findsNothing);
      expect(find.text('Kịch bản'), findsOneWidget);
    });
  });
}
