import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/services/speech_recognizer.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/presentation/screens/shadowing_screen.dart';

class _FakeRecognizer implements SpeechRecognizer {
  bool available = true;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start({
    required Duration listenFor,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(double level) onLevel,
  }) async {}

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
];

Widget _app(SpeechRecognizer recognizer) => MaterialApp(
  home: ShadowingScreen(videoId: '1', cues: _cues, recognizer: recognizer),
);

void main() {
  testWidgets('hiện câu, bản dịch, nút nghe mẫu và micro', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()));

    expect(find.text('Luyện nói theo'), findsOneWidget);
    expect(find.text('私の名前はロックです。'), findsOneWidget);
    expect(find.text('Tên tôi là Lộc.'), findsOneWidget);
    expect(find.text('Nghe mẫu'), findsOneWidget);
    expect(find.text('Chạm để bắt đầu nói'), findsOneWidget);
  });

  testWidgets('bấm micro thì chuyển sang đang nghe, có nút dừng', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()));

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(find.text('Đang nghe bạn nói...'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('thiết bị không hỗ trợ thì báo lỗi dễ hiểu', (tester) async {
    await tester.pumpWidget(_app(_FakeRecognizer()..available = false));

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(find.textContaining('chưa hỗ trợ nhận dạng giọng nói'), findsOneWidget);
    expect(find.text('Chạm để thử lại'), findsOneWidget);
  });

  testWidgets('video không có kịch bản', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShadowingScreen(videoId: '1', cues: const [], recognizer: _FakeRecognizer()),
      ),
    );
    expect(find.textContaining('chưa có kịch bản'), findsOneWidget);
  });
}
