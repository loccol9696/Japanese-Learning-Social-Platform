import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

/// Một từ trong câu phụ đề (đã tách bởi backend).
class SubtitleToken {
  final String surface;
  final String baseForm;
  final String reading;
  final bool lookupable;

  const SubtitleToken({
    required this.surface,
    required this.baseForm,
    required this.reading,
    required this.lookupable,
  });

  factory SubtitleToken.fromJson(Map<String, dynamic> json) {
    final surface = json['surface']?.toString() ?? '';
    final baseForm = json['baseForm']?.toString() ?? '';
    return SubtitleToken(
      surface: surface,
      baseForm: baseForm.isNotEmpty ? baseForm : surface,
      reading: json['reading']?.toString() ?? '',
      lookupable: json['lookupable'] == true,
    );
  }
}

/// Kết quả tra 1 từ.
class WordLookup {
  final String term;
  final String reading;
  final String meaningVi;
  final String meaningEn;
  final String jlptLevel;
  final String partOfSpeech;
  final bool found;

  const WordLookup({
    required this.term,
    required this.reading,
    required this.meaningVi,
    required this.meaningEn,
    required this.jlptLevel,
    required this.partOfSpeech,
    required this.found,
  });

  /// Nghĩa hiển thị: ưu tiên tiếng Việt, không có thì dùng tiếng Anh.
  String get meaning => meaningVi.isNotEmpty ? meaningVi : meaningEn;

  factory WordLookup.fromJson(Map<String, dynamic> json) {
    return WordLookup(
      term: json['term']?.toString() ?? '',
      reading: json['reading']?.toString() ?? '',
      meaningVi: json['meaningVi']?.toString() ?? '',
      meaningEn: json['meaningEn']?.toString() ?? '',
      jlptLevel: json['jlptLevel']?.toString() ?? '',
      partOfSpeech: json['partOfSpeech']?.toString() ?? '',
      found: json['found'] == true,
    );
  }
}

class DictionaryService {
  static DictionaryService? _instance;
  DictionaryService._();
  static DictionaryService get instance => _instance ??= DictionaryService._();

  final ApiClient _api = ApiClient.instance;

  // Cache theo câu / theo từ, và gộp các request trùng đang chạy.
  final Map<String, Future<List<SubtitleToken>>> _tokenCache = {};
  final Map<String, Future<WordLookup>> _lookupCache = {};

  Future<List<SubtitleToken>> tokenize(String text) {
    return _tokenCache.putIfAbsent(text, () async {
      try {
        final uri = Uri.parse(ApiConstants.dictionaryTokenizeUrl)
            .replace(queryParameters: {'text': text});
        final res = await _api.get(uri.toString());
        if (res is! List) return const <SubtitleToken>[];
        return res
            .whereType<Map<String, dynamic>>()
            .map(SubtitleToken.fromJson)
            .where((t) => t.surface.isNotEmpty)
            .toList();
      } catch (_) {
        _tokenCache.remove(text); // cho phép thử lại lần sau
        rethrow;
      }
    });
  }

  Future<WordLookup> lookup(String word) {
    return _lookupCache.putIfAbsent(word, () async {
      try {
        final uri = Uri.parse(ApiConstants.dictionaryLookupUrl)
            .replace(queryParameters: {'word': word});
        final res = await _api.get(uri.toString());
        final result = WordLookup.fromJson(res as Map<String, dynamic>);
        if (!result.found) _lookupCache.remove(word);
        return result;
      } catch (_) {
        _lookupCache.remove(word);
        rethrow;
      }
    });
  }
}
