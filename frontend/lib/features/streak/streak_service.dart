import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import 'streak_calendar.dart';
import 'streak_model.dart';

class StreakService {
  StreakService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<Streak> getMine() async {
    final res = await _api.get(ApiConstants.streakUrl, withAuth: true);
    return res is Map<String, dynamic> ? Streak.fromJson(res) : const Streak();
  }

  /// Các ngày đã học trong [from, to] (tối đa 62 ngày), dạng ngày không kèm giờ.
  Future<Set<DateTime>> getDays(DateTime from, DateTime to) async {
    final res = await _api.get(ApiConstants.streakDaysUrl(from, to), withAuth: true);
    if (res is! List) return {};
    return {
      for (final item in res)
        if (DateTime.tryParse(item.toString()) case final parsed?) dateOnly(parsed),
    };
  }
}
