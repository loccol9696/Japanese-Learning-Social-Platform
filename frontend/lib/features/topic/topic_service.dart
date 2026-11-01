import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../profile/domain/models/topic_model.dart';

/// Danh sách chủ đề đang hiển thị (công khai), dùng cho upload video và lọc Khám phá.
class TopicService {
  TopicService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<TopicModel>> fetchTopics() async {
    final data = await _api.get(ApiConstants.topicsUrl, withAuth: false);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(TopicModel.fromJson)
        .where((t) => t.id > 0 && t.name.isNotEmpty)
        .toList();
  }
}
