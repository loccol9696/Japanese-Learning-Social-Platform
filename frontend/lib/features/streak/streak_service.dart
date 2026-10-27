import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import 'streak_model.dart';

class StreakService {
  StreakService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<Streak> getMine() async {
    final res = await _api.get(ApiConstants.streakUrl, withAuth: true);
    return res is Map<String, dynamic> ? Streak.fromJson(res) : const Streak();
  }
}
