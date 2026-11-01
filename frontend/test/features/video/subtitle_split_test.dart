import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/video/presentation/subtitle_split.dart';

void main() {
  test('định dạng và đọc lại thời gian giữ một chữ số thập phân', () {
    expect(formatSubtitleTime(3.54), '00:03.5');
    expect(formatSubtitleTime(65.0), '01:05.0');
    expect(parseSubtitleTime('01:05.5'), 65.5);
    expect(parseSubtitleTime('00:09'), 9);
    expect(parseSubtitleTime('hỏng'), 0);
  });

  test('tách tại con trỏ: thời gian chia theo tỉ lệ ký tự', () {
    final r = splitSubtitleAt(
      text: '私はまたラボに戻らなくてはならないんだ。ほら、さっさと出したまえ。',
      translation: 'Tôi phải quay lại phòng thí nghiệm. Thôi nào ra khỏi đây thôi.',
      start: '00:10',
      end: '00:20',
      offset: 20,
    )!;

    expect(r.firstText, '私はまたラボに戻らなくてはならないんだ。');
    expect(r.secondText, 'ほら、さっさと出したまえ。');
    expect(r.firstStart, '00:10.0');
    expect(r.secondEnd, '00:20.0');
    expect(r.firstEnd, r.secondStart);
    expect(parseSubtitleTime(r.firstEnd), greaterThan(10));
    expect(parseSubtitleTime(r.firstEnd), lessThan(20));
    expect(r.firstTranslation, isNotEmpty);
    expect(r.secondTranslation, isNotEmpty);
    expect(
      '${r.firstTranslation} ${r.secondTranslation}',
      'Tôi phải quay lại phòng thí nghiệm. Thôi nào ra khỏi đây thôi.',
    );
  });

  test('không tách được khi con trỏ ở đầu/cuối hoặc dòng trống', () {
    SubtitleSplitResult? run(String text, int offset) => splitSubtitleAt(
      text: text,
      translation: '',
      start: '00:00',
      end: '00:05',
      offset: offset,
    );
    expect(run('こんにちは', 0), isNull);
    expect(run('こんにちは', 5), isNull);
    expect(run('こんにちは', -1), isNull);
    expect(run('   ', 1), isNull);
  });
}
