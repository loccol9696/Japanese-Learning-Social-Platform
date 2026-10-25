/// Tách một dòng phụ đề thành hai dòng tại vị trí con trỏ.
class SubtitleSplitResult {
  final String firstText;
  final String secondText;
  final String firstTranslation;
  final String secondTranslation;
  final String firstStart;
  final String firstEnd;
  final String secondStart;
  final String secondEnd;

  const SubtitleSplitResult({
    required this.firstText,
    required this.secondText,
    required this.firstTranslation,
    required this.secondTranslation,
    required this.firstStart,
    required this.firstEnd,
    required this.secondStart,
    required this.secondEnd,
  });
}

/// Đổi "MM:SS" hoặc "MM:SS.s" sang số giây.
double parseSubtitleTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return 0;
  final minutes = int.tryParse(parts[0]) ?? 0;
  final seconds = double.tryParse(parts[1]) ?? 0;
  return minutes * 60 + seconds;
}

/// Định dạng số giây thành "MM:SS.s" (một chữ số thập phân để câu ngắn vẫn có độ dài).
String formatSubtitleTime(double seconds) {
  final tenths = (seconds * 10).round();
  final minutes = tenths ~/ 600;
  final rest = (tenths % 600) / 10;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toStringAsFixed(1).padLeft(4, '0')}';
}

/// Cắt [text] tại [offset]; thời gian chia theo tỉ lệ số ký tự, bản dịch cắt ở khoảng trắng gần
/// vị trí tương ứng nhất. Trả null nếu không cắt được (con trỏ ở đầu/cuối hoặc dòng chỉ có khoảng trắng).
SubtitleSplitResult? splitSubtitleAt({
  required String text,
  required String translation,
  required String start,
  required String end,
  required int offset,
}) {
  if (offset <= 0 || offset >= text.length) return null;
  final first = text.substring(0, offset).trim();
  final second = text.substring(offset).trim();
  if (first.isEmpty || second.isEmpty) return null;

  final from = parseSubtitleTime(start);
  final to = parseSubtitleTime(end);
  final ratio = offset / text.length;
  final mid = from + (to - from) * ratio;

  var firstTranslation = translation.trim();
  var secondTranslation = '';
  if (firstTranslation.isNotEmpty) {
    final target = (firstTranslation.length * ratio).round();
    var cut = -1;
    var best = firstTranslation.length;
    for (var i = 0; i < firstTranslation.length; i++) {
      if (firstTranslation[i] == ' ' && (i - target).abs() < best) {
        best = (i - target).abs();
        cut = i;
      }
    }
    if (cut > 0) {
      secondTranslation = firstTranslation.substring(cut + 1).trim();
      firstTranslation = firstTranslation.substring(0, cut).trim();
    }
  }

  return SubtitleSplitResult(
    firstText: first,
    secondText: second,
    firstTranslation: firstTranslation,
    secondTranslation: secondTranslation,
    firstStart: formatSubtitleTime(from),
    firstEnd: formatSubtitleTime(mid),
    secondStart: formatSubtitleTime(mid),
    secondEnd: formatSubtitleTime(to),
  );
}
