/// Số chủ đề tối đa trên một video, khớp giới hạn ở server.
const int maxTopicsPerVideo = 3;

/// Số hashtag tối đa trên một video, khớp giới hạn ở server.
const int maxHashtagsPerVideo = 5;

const int maxHashtagLength = 30;

/// Chữ cái, dấu kết hợp, chữ số và "_" của mọi ngôn ngữ (gồm kana, kanji).
final RegExp _validHashtag = RegExp(
  '^[\\p{L}\\p{M}\\p{N}_]{1,$maxHashtagLength}\$',
  unicode: true,
);

/// Bỏ dấu "#" đầu và viết thường, để "#Anime" và "anime" là cùng một thẻ.
/// Server chuẩn hoá lại lần nữa nên đây chỉ cần đủ để hiển thị và loại trùng.
String normalizeHashtag(String raw) {
  return raw.trim().replaceFirst(RegExp(r'^[#＃]+'), '').toLowerCase();
}

bool isValidHashtag(String normalized) => _validHashtag.hasMatch(normalized);

/// Đọc danh sách hashtag từ JSON của video.
List<String> parseHashtags(dynamic json) {
  if (json is! List) return const [];
  return json.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}
