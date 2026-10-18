import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Định dạng số giây thành `mm:ss` (làm tròn tới giây).
String formatMmSs(num seconds) {
  final wholeSeconds = seconds.round();
  final minutes = wholeSeconds ~/ 60;
  final remainder = wholeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

/// Một dòng phụ đề đang soạn ở màn đăng video (giữ controller để sửa trực tiếp).
class SubtitleDraft {
  final String start;
  final String end;
  final japanese = TextEditingController();
  final translation = TextEditingController();
  bool editing;

  SubtitleDraft({
    required this.start,
    required this.end,
    String japaneseText = '',
    String translationText = '',
    this.editing = true,
  }) {
    japanese.text = japaneseText;
    translation.text = translationText;
  }

  /// Từ một segment của API Speech-to-Text (`startTime`/`endTime` tính bằng giây).
  factory SubtitleDraft.fromAiSegment(Map<String, dynamic> segment) {
    return SubtitleDraft(
      start: formatMmSs((segment['startTime'] as num?)?.toDouble() ?? 0),
      end: formatMmSs((segment['endTime'] as num?)?.toDouble() ?? 0),
      japaneseText: segment['text']?.toString() ?? '',
      translationText: segment['translatedText']?.toString() ?? '',
      editing: false,
    );
  }

  /// JSON gửi lên field `subtitles` của video; bỏ dòng trống, `null` nếu không còn dòng nào.
  static String? encodeList(List<SubtitleDraft> subtitles) {
    final items = subtitles
        .where((subtitle) => subtitle.japanese.text.trim().isNotEmpty)
        .map(
          (subtitle) => {
            'start': subtitle.start,
            'end': subtitle.end,
            'text': subtitle.japanese.text.trim(),
            'translation': subtitle.translation.text.trim(),
          },
        )
        .toList();
    return items.isEmpty ? null : jsonEncode(items);
  }

  void dispose() {
    japanese.dispose();
    translation.dispose();
  }
}
