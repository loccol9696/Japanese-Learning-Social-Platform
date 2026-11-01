import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/services/speech_recognizer.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/domain/models/shadowing_models.dart';
import 'package:frontend/features/home/presentation/controllers/shadowing_controller.dart';

class FakeRecognizer implements SpeechRecognizer {
  bool available = true;
  void Function(String text)? _onFinal;
  void Function(double level)? _onLevel;
  void Function(String code)? _onError;
  void Function(String text)? _onPartial;
  bool cancelled = false;
  Duration? lastListenFor;

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
    lastListenFor = listenFor;
    _onFinal = onFinal;
    _onLevel = onLevel;
    _onError = onError;
    _onPartial = onPartial;
  }

  void say(String text) => _onFinal?.call(text);
  void level(double v) => _onLevel?.call(v);
  void fail(String code) => _onError?.call(code);
  void partial(String text) => _onPartial?.call(text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async => cancelled = true;
}

SubtitleCue _cue(int i) => SubtitleCue(
  start: Duration(seconds: i * 4),
  end: Duration(seconds: i * 4 + 3),
  text: 'câu $i',
  translation: 'dịch $i',
);

ShadowingLineScore _score(int index, int score, {int? best}) => ShadowingLineScore(
  lineIndex: index,
  expectedText: 'câu $index',
  recognizedText: 'x',
  score: score,
  level: 'GOOD',
  words: const [],
  bestScore: best ?? score,
);

void main() {
  late FakeRecognizer recognizer;
  late List<(int, String)> scored;
  late Map<int, int> scoresToReturn;
  late int samplesPlayed;

  ShadowingController build({int cueCount = 3, int startIndex = 0, Map<int, int>? best}) {
    scored = [];
    samplesPlayed = 0;
    return ShadowingController(
      cues: List.generate(cueCount, _cue),
      recognizer: recognizer,
      startIndex: startIndex,
      bestScores: best,
      playSample: (cue) async => samplesPlayed++,
      scoreLine: (index, text) async {
        scored.add((index, text));
        return _score(index, scoresToReturn[index] ?? 80);
      },
    );
  }

  setUp(() {
    recognizer = FakeRecognizer();
    scoresToReturn = {};
  });

  test('luồng đầy đủ: sẵn sàng → nghe → chấm → có kết quả', () async {
    final c = build();
    expect(c.phase, ShadowingPhase.ready);

    await c.startListening();
    expect(c.phase, ShadowingPhase.listening);

    recognizer.say('こんにちは');
    await Future<void>.delayed(Duration.zero);

    expect(c.phase, ShadowingPhase.result);
    expect(c.result!.score, 80);
    expect(scored.single, (0, 'こんにちは'));
  });

  test('thời gian nghe tối đa gấp đôi độ dài câu cộng 2 giây', () async {
    final c = build();
    await c.startListening();
    expect(recognizer.lastListenFor, const Duration(seconds: 8));
  });

  test('không nghe thấy gì thì báo lỗi và không gọi server', () async {
    final c = build();
    await c.startListening();
    recognizer.say('   ');
    await Future<void>.delayed(Duration.zero);

    expect(c.phase, ShadowingPhase.error);
    expect(c.error, contains('Không nghe thấy'));
    expect(scored, isEmpty);
  });

  test('thiết bị không hỗ trợ nhận dạng giọng nói', () async {
    recognizer.available = false;
    final c = build();
    await c.startListening();

    expect(c.phase, ShadowingPhase.error);
    expect(c.error, contains('micro'));
  });

  test('lỗi mạng khi chấm thì báo lỗi, cho phép thử lại', () async {
    final c = ShadowingController(
      cues: [_cue(0)],
      recognizer: recognizer,
      playSample: (cue) async {},
      scoreLine: (i, t) async => throw Exception('offline'),
    );
    await c.startListening();
    recognizer.say('abc');
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, ShadowingPhase.error);

    c.retry();
    expect(c.phase, ShadowingPhase.ready);
  });

  test('kết quả đến hai lần chỉ được chấm một lần', () async {
    final c = build();
    await c.startListening();
    recognizer.say('一回');
    recognizer.say('二回');
    await Future<void>.delayed(Duration.zero);
    expect(scored.length, 1);
  });

  test('câu tiếp theo, câu cuối dẫn tới tổng kết', () async {
    final c = build(cueCount: 2);
    scoresToReturn = {0: 90, 1: 40};

    await c.startListening();
    recognizer.say('a');
    await Future<void>.delayed(Duration.zero);
    expect(c.isLast, isFalse);
    c.next();
    expect(c.lineIndex, 1);
    expect(c.phase, ShadowingPhase.ready);

    await c.startListening();
    recognizer.say('b');
    await Future<void>.delayed(Duration.zero);
    expect(c.isLast, isTrue);
    c.next();

    expect(c.phase, ShadowingPhase.summary);
    expect(c.sessionAverage, 65);
    expect(c.weakLines, [1]);
  });

  test('bắt đầu từ dòng được chọn và luyện lại các câu yếu', () async {
    final c = build(cueCount: 4, startIndex: 2);
    scoresToReturn = {2: 30, 3: 95};
    expect(c.lineIndex, 2);

    for (var i = 0; i < 2; i++) {
      await c.startListening();
      recognizer.say('x');
      await Future<void>.delayed(Duration.zero);
      c.next();
    }
    expect(c.phase, ShadowingPhase.summary);
    expect(c.weakLines, [2]);

    c.practiceWeakLines();
    expect(c.phase, ShadowingPhase.ready);
    expect(c.lineIndex, 2);
    expect(c.isLast, isTrue);
    expect(c.practicedCount, 0);
  });

  test('điểm cao nhất giữ giá trị lớn nhất kể cả khi lần này thấp hơn', () async {
    final c = build(best: {0: 95});
    scoresToReturn = {0: 60};
    await c.startListening();
    recognizer.say('x');
    await Future<void>.delayed(Duration.zero);
    expect(c.result!.score, 60);
    expect(c.bestScores[0], 95);
  });

  test('nghe mẫu quay lại trạng thái trước đó', () async {
    final c = build();
    await c.listenSample();
    expect(samplesPlayed, 1);
    expect(c.phase, ShadowingPhase.ready);
  });

  test('lỗi micro từ trình duyệt được dịch sang thông báo dễ hiểu', () async {
    final c = build();
    await c.startListening();
    recognizer.fail('not-allowed');
    expect(c.phase, ShadowingPhase.error);
    expect(c.error, contains('micro'));
    expect(c.error, contains('not-allowed'));

    c.retry();
    await c.startListening();
    recognizer.fail('network');
    expect(c.error, contains('mạng'));
  });

  test('câu đang nghe được cập nhật ngay khi có kết quả tạm', () async {
    final c = build();
    await c.startListening();
    recognizer.partial('もちろん');
    expect(c.partialText, 'もちろん');
  });

  test('mức âm lượng cập nhật khi đang nghe', () async {
    final c = build();
    await c.startListening();
    recognizer.level(0.7);
    expect(c.level, 0.7);
  });
}
