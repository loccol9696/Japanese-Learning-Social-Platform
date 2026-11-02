import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/presentation/screens/video_script_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('scriptVideoHeight', () {
    test('video ngang 16:9: khung vừa khít, không chừa khoảng trống trên dưới', () {
      expect(scriptVideoHeight(const Size(410, 850), aspectRatio: 16 / 9), closeTo(410 * 9 / 16, 0.01));
    });

    test('video ngang tỉ lệ khác 16:9 cũng vừa khít theo tỉ lệ thật', () {
      expect(scriptVideoHeight(const Size(400, 900), aspectRatio: 2.0), closeTo(200, 0.01));
      expect(scriptVideoHeight(const Size(400, 900), aspectRatio: 4 / 3), closeTo(300, 0.01));
    });

    test('chưa biết tỉ lệ (video chưa tải) thì tạm dùng 16:9', () {
      expect(scriptVideoHeight(const Size(410, 850)), closeTo(410 * 9 / 16, 0.01));
      expect(scriptVideoHeight(const Size(410, 850), aspectRatio: 0), closeTo(410 * 9 / 16, 0.01));
    });

    test('video dọc hoặc vuông bị chặn ở 42% chiều cao màn để còn chỗ cho danh sách', () {
      expect(scriptVideoHeight(const Size(410, 850), aspectRatio: 9 / 16), closeTo(850 * 0.42, 0.01));
      expect(scriptVideoHeight(const Size(410, 850), aspectRatio: 1), closeTo(850 * 0.42, 0.01));
    });

    test('màn thấp cũng không vượt 42% chiều cao', () {
      expect(scriptVideoHeight(const Size(410, 400), aspectRatio: 16 / 9), closeTo(168, 0.01));
    });
  });

  testWidgets('khung video (chưa tải) dùng 16:9 và tiêu đề / nút quay lại như thiết kế', (tester) async {
    tester.view.physicalSize = const Size(410, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: VideoScriptScreen(cues: [], controller: null),
    ));

    expect(tester.getSize(find.byKey(const ValueKey('script-video-area'))).height, closeTo(410 * 9 / 16, 0.01));
    expect(find.text('Kịch bản'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  group('nút báo cáo bản dịch', () {
    const translated = SubtitleCue(
      start: Duration.zero,
      end: Duration(seconds: 1),
      text: 'こんにちは',
      translation: 'Xin chào',
      sourceIndex: 4,
    );
    const untranslated = SubtitleCue(
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      text: 'さようなら',
      translation: '',
      sourceIndex: 5,
    );

    Future<void> pump(WidgetTester tester, {required bool canReport}) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: VideoScriptScreen(
          cues: const [translated, untranslated],
          controller: null,
          videoId: '12',
          canReport: canReport,
        ),
      ));
      await tester.pump();
    }

    testWidgets('chỉ câu có bản dịch mới có nút', (tester) async {
      await pump(tester, canReport: true);

      expect(find.byKey(const ValueKey('report-translation-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('report-translation-1')), findsNothing);
    });

    testWidgets('video của chính mình không có nút', (tester) async {
      await pump(tester, canReport: false);

      expect(find.byKey(const ValueKey('report-translation-0')), findsNothing);
    });
  });
}
