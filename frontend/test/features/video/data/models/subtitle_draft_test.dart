import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/video/data/models/subtitle_draft.dart';

void main() {
  test('formatMmSs làm tròn và đệm 0', () {
    expect(formatMmSs(0), '00:00');
    expect(formatMmSs(3.6), '00:04');
    expect(formatMmSs(75), '01:15');
    expect(formatMmSs(600), '10:00');
  });

  test('fromAiSegment đọc thời gian, nội dung và ở chế độ xem', () {
    final draft = SubtitleDraft.fromAiSegment({
      'startTime': 64,
      'endTime': 70.2,
      'text': 'ありがとう',
      'translatedText': 'Cảm ơn',
    });

    expect(draft.start, '01:04');
    expect(draft.end, '01:10');
    expect(draft.japanese.text, 'ありがとう');
    expect(draft.translation.text, 'Cảm ơn');
    expect(draft.editing, isFalse);
  });

  test('fromAiSegment chịu được segment thiếu field', () {
    final draft = SubtitleDraft.fromAiSegment({});
    expect(draft.start, '00:00');
    expect(draft.japanese.text, '');
  });

  test('encodeList bỏ dòng tiếng Nhật trống và trim nội dung', () {
    final drafts = [
      SubtitleDraft(start: '00:00', end: '00:03', japaneseText: ' こんにちは ', translationText: ' Xin chào '),
      SubtitleDraft(start: '00:03', end: '00:05', japaneseText: '   '),
    ];

    expect(jsonDecode(SubtitleDraft.encodeList(drafts)!), [
      {'start': '00:00', 'end': '00:03', 'text': 'こんにちは', 'translation': 'Xin chào'},
    ]);
    expect(SubtitleDraft.encodeList([drafts[1]]), isNull);
    expect(SubtitleDraft.encodeList([]), isNull);
  });
}
