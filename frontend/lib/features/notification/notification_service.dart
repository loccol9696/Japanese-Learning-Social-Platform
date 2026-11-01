import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import 'notification_model.dart';

/// Gọi REST API thông báo của người đang đăng nhập.
class NotificationService {
  NotificationService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<NotificationPage> fetch({int page = 0, int size = 20}) async {
    final data = await _api.get(
      '${ApiConstants.notificationsUrl}?page=$page&size=$size',
    );
    if (data is! Map<String, dynamic> || data['content'] is! List) {
      throw const FormatException('Backend trả về danh sách thông báo không hợp lệ.');
    }
    final items = (data['content'] as List)
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
    return NotificationPage(items: items, isLast: data['last'] != false);
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get('${ApiConstants.notificationsUrl}/unread-count');
    final count = data is Map<String, dynamic> ? data['count'] : null;
    return count is num ? count.toInt() : 0;
  }

  Future<void> markRead(int id) async {
    await _api.post('${ApiConstants.notificationsUrl}/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post('${ApiConstants.notificationsUrl}/read-all');
  }
}
