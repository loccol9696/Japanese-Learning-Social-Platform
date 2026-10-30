import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/notification_models.dart';

/// Gọi REST API của thông báo. Thông báo mới đến realtime qua socket
/// (xem `ChatSocketService.onNotification`); các hàm ở đây dùng để tải danh sách
/// và đánh dấu đã đọc.
class NotificationService {
  NotificationService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  Future<NotificationPage> fetchPage(
    NotificationCategory category, {
    int page = 0,
    int size = 20,
  }) async {
    final data = await _api.get(
      '${ApiConstants.notificationsUrl}'
      '?category=${category.apiValue}&page=$page&size=$size',
    );
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Backend trả về dữ liệu thông báo không hợp lệ.',
      );
    }
    return NotificationPage.fromJson(data);
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get(ApiConstants.notificationsUnreadCountUrl);
    final count = data is Map<String, dynamic> ? data['count'] : 0;
    return count is num ? count.toInt() : 0;
  }

  Future<void> markRead(int id) async {
    await _api.post(ApiConstants.notificationReadUrl(id));
  }

  Future<void> markAllRead() async {
    await _api.post(ApiConstants.notificationsReadAllUrl);
  }
}
