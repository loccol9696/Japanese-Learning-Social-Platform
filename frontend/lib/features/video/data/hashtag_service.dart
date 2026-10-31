import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Gợi ý hashtag đã có trên video công khai, để người đăng dùng lại thẻ sẵn có thay vì tạo thẻ na ná.
class HashtagService {
  HashtagService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<String>> suggest(String query) async {
    final uri = Uri.parse(ApiConstants.hashtagSuggestUrl)
        .replace(queryParameters: {'q': query});
    final data = await _api.get(uri.toString(), withAuth: false);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => e['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
